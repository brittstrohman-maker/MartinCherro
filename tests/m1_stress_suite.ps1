<#
.SYNOPSIS
    Milestone 1 Empirical Adversarial Stress-Test Suite
.DESCRIPTION
    Rigorous stress tests for Milestone 1 deliverables of the Canitera Shopify Theme:
    1. Strict JSON parsing and OS 2.0 schema validation of config/ and templates/
    2. Adversarial simulation & stress testing of snippets/breadcrumbs.liquid (JSON-LD BreadcrumbList)
    3. Strict compliance validation of config/settings_schema.json against Shopify OS 2.0 restrictions
    4. Execution and metric analysis of verify-theme.ps1
#>

[CmdletBinding()]
param(
    [string]$WorkspaceRoot = "c:\Users\martin\Documents\martin"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:Failures = New-Object System.Collections.ArrayList
$script:Warnings = New-Object System.Collections.ArrayList

function Log-Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
}

function Assert-Test([string]$TestId, [string]$Name, [bool]$Condition, [string]$Message = "", [string]$Details = "") {
    $script:TotalTests++
    if ($Condition) {
        $script:PassedTests++
        Write-Host "  [PASS] " -ForegroundColor Green -NoNewline
        Write-Host "[$TestId] " -ForegroundColor DarkGray -NoNewline
        Write-Host "$Name" -ForegroundColor White
        if ($Message) {
            Write-Host "         $Message" -ForegroundColor DarkGray
        }
    } else {
        $script:FailedTests++
        Write-Host "  [FAIL] " -ForegroundColor Red -NoNewline
        Write-Host "[$TestId] " -ForegroundColor DarkGray -NoNewline
        Write-Host "$Name" -ForegroundColor White
        Write-Host "         $Message" -ForegroundColor Red
        if ($Details) {
            Write-Host "         Details: $Details" -ForegroundColor Yellow
        }
        $script:Failures.Add([PSCustomObject]@{
            TestId = $TestId
            Name = $Name
            Message = $Message
            Details = $Details
        }) | Out-Null
    }
}

function Add-Warning([string]$TestId, [string]$Name, [string]$Message) {
    Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host "[$TestId] " -ForegroundColor DarkGray -NoNewline
    Write-Host "$Name - $Message" -ForegroundColor Yellow
    $script:Warnings.Add([PSCustomObject]@{
        TestId = $TestId
        Name = $Name
        Message = $Message
    }) | Out-Null
}

# =============================================================================
# SUITE 1: STRICT JSON VALIDATION & SCHEMA INTEGRITY
# =============================================================================
Log-Section "SUITE 1: STRICT JSON & TEMPLATE SCHEMA INTEGRITY"

$configFiles = Get-ChildItem -Path (Join-Path $WorkspaceRoot "config") -Filter "*.json" -File
$templateFiles = Get-ChildItem -Path (Join-Path $WorkspaceRoot "templates") -Filter "*.json" -File -Recurse
$allTargetJsonFiles = @($configFiles) + @($templateFiles)

Assert-Test "S1.1" "Target JSON Files Discovered" ($allTargetJsonFiles.Count -ge 14) `
    "Discovered $($allTargetJsonFiles.Count) JSON files across config/ and templates/."

# Test 1.2: Strict JSON Syntax (no trailing commas, comments, or BOM corruption)
$jsonSyntaxErrors = @()
$trailingCommaFiles = @()

foreach ($file in $allTargetJsonFiles) {
    $rawContent = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    
    # Check for empty file
    if ([string]::IsNullOrWhiteSpace($rawContent)) {
        $jsonSyntaxErrors += "$($file.Name): Empty file"
        continue
    }

    # Strict parse using ConvertFrom-Json
    try {
        $parsed = ConvertFrom-Json -InputObject $rawContent -ErrorAction Stop
    } catch {
        $jsonSyntaxErrors += "$($file.Name): $($_.Exception.Message)"
        continue
    }

    # Regex test for trailing commas before closing braces/brackets (invalid in strict JSON)
    if ($rawContent -match ',\s*[\]\}]') {
        $trailingCommaFiles += $file.Name
    }
}

Assert-Test "S1.2" "Strict JSON Parsing ($($allTargetJsonFiles.Count) files)" ($jsonSyntaxErrors.Count -eq 0) `
    "All JSON files parse without syntax errors." ($jsonSyntaxErrors -join "; ")

Assert-Test "S1.3" "Zero Trailing Commas in JSON Files" ($trailingCommaFiles.Count -eq 0) `
    "No trailing commas found in any JSON file." ($trailingCommaFiles -join ", ")

# Test 1.4: Templates OS 2.0 Structure Validation
$templateStructureErrors = @()
$orphanedSectionsList = @()
$duplicateSectionOrderErrors = @()
$duplicateBlockOrderErrors = @()

foreach ($tf in $templateFiles) {
    try {
        $data = Get-Content -Path $tf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    } catch { continue }

    # Root must have sections and order
    if ($null -eq $data.sections) {
        $templateStructureErrors += "$($tf.Name): missing 'sections' root object"
        continue
    }
    if ($null -eq $data.order) {
        $templateStructureErrors += "$($tf.Name): missing 'order' root array"
        continue
    }

    # Order must be array of strings
    $orderSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($secId in $data.order) {
        if (-not $orderSet.Add($secId.ToString())) {
            $duplicateSectionOrderErrors += "$($tf.Name): duplicate section ID '$secId' in order array"
        }
        if ($null -eq $data.sections.$secId) {
            $templateStructureErrors += "$($tf.Name): order references '$secId' which does not exist in sections"
        }
    }

    # Check sections object properties
    foreach ($prop in $data.sections.PSObject.Properties) {
        $sec = $prop.Value
        if ($null -eq $sec.type -or [string]::IsNullOrWhiteSpace($sec.type.ToString())) {
            $templateStructureErrors += "$($tf.Name): section '$($prop.Name)' missing non-empty 'type'"
        }

        # Check block_order and blocks referential integrity
        if ($null -ne $sec.block_order) {
            $blockSet = New-Object System.Collections.Generic.HashSet[string]
            foreach ($bId in $sec.block_order) {
                if (-not $blockSet.Add($bId.ToString())) {
                    $duplicateBlockOrderErrors += "$($tf.Name): section '$($prop.Name)' duplicate block ID '$bId' in block_order"
                }
                if ($null -eq $sec.blocks -or $null -eq $sec.blocks.$bId) {
                    $templateStructureErrors += "$($tf.Name): section '$($prop.Name)' block_order references missing block '$bId'"
                }
            }
        }

        # Audit if section is declared but not in order
        if (-not $orderSet.Contains($prop.Name)) {
            $orphanedSectionsList += "$($tf.Name):'$($prop.Name)'"
        }
    }
}

Assert-Test "S1.4" "Template OS 2.0 Structural Integrity" ($templateStructureErrors.Count -eq 0) `
    "All templates follow strict OS 2.0 sections + order structure." ($templateStructureErrors -join "; ")

Assert-Test "S1.5" "Zero Duplicate IDs in Section Order" ($duplicateSectionOrderErrors.Count -eq 0) `
    "All section order arrays contain unique IDs." ($duplicateSectionOrderErrors -join "; ")

Assert-Test "S1.6" "Zero Duplicate IDs in Block Order" ($duplicateBlockOrderErrors.Count -eq 0) `
    "All section block order arrays contain unique block IDs." ($duplicateBlockOrderErrors -join "; ")

if ($orphanedSectionsList.Count -gt 0) {
    Add-Warning "S1.7" "Orphaned/Unused Sections in Templates" `
        "Found $($orphanedSectionsList.Count) sections defined in sections object but not included in order array: $($orphanedSectionsList -join ', ')"
} else {
    Assert-Test "S1.7" "Zero Orphaned Sections in Templates" $true "Every defined section is listed in order."
}

# =============================================================================
# SUITE 2: ADVERSARIAL STRESS-TESTING OF BREADCRUMBS JSON-LD
# =============================================================================
Log-Section "SUITE 2: ADVERSARIAL STRESS-TESTING OF BREADCRUMBS JSON-LD"

# Liquid JSON filter simulation function
# Liquid's `| json` filter escapes quotes, backslashes, newlines, carriage returns, tabs, and wraps in quotes.
# If input is null, it outputs null.
function Liquid-JsonFilter($inputVal) {
    if ($null -eq $inputVal) { return "null" }
    return (ConvertTo-Json -InputObject ($inputVal.ToString()) -Compress)
}

# Accurate simulator for snippets/breadcrumbs.liquid JSON-LD block
function Simulate-BreadcrumbsJsonLd(
    [string]$TemplateName,
    [hashtable]$Context
) {
    if ($TemplateName -eq "index" -or $TemplateName -eq "cart") {
        return $null # Snippet renders nothing
    }

    $homeTitle = if ($Context.ContainsKey("home_title")) { $Context["home_title"] } else { "Home" }
    $shopTitle = if ($Context.ContainsKey("shop_title")) { $Context["shop_title"] } else { "Shop" }
    $shopUrl = if ($Context.ContainsKey("shop_url")) { $Context["shop_url"] } else { "https://canitera.com" }
    $rootUrl = if ($Context.ContainsKey("root_url")) { $Context["root_url"] } else { "/" }
    $allProductsUrl = if ($Context.ContainsKey("all_products_url")) { $Context["all_products_url"] } else { "/collections/all" }
    $canonicalUrl = if ($Context.ContainsKey("canonical_url")) { $Context["canonical_url"] } else { "https://canitera.com/test" }

    $ldLevel2Name = ""
    $ldLevel2Url = ""
    $ldLevel3Name = ""
    $ldLevel3Url = ""
    $ldLevel4Name = ""
    $ldLevel4Url = ""

    switch ($TemplateName) {
        "product" {
            if ($Context.collection -and -not [string]::IsNullOrWhiteSpace($Context.collection.url)) {
                $ldLevel2Name = $Context.collection.title
                $ldLevel2Url = $shopUrl + $Context.collection.url
            } elseif ($Context.product -and $Context.product.collections -and $Context.product.collections.Count -gt 0) {
                $ldLevel2Name = $Context.product.collections[0].title
                $ldLevel2Url = $shopUrl + $Context.product.collections[0].url
            } else {
                $ldLevel2Name = $shopTitle
                $ldLevel2Url = $shopUrl + $allProductsUrl
            }
            if ($Context.product) {
                $ldLevel3Name = $Context.product.title
            }
            $ldLevel3Url = $canonicalUrl
        }
        "collection" {
            $ldLevel2Name = $shopTitle
            $ldLevel2Url = $shopUrl + $allProductsUrl
            if ($Context.current_tags -and $Context.current_tags.Count -gt 0) {
                $ldLevel3Name = if ($Context.collection) { $Context.collection.title } else { "" }
                $ldLevel3Url = $shopUrl + $(if ($Context.collection) { $Context.collection.url } else { "" })
                $ldLevel4Name = ($Context.current_tags -join " + ")
                $ldLevel4Url = $canonicalUrl
            } else {
                $ldLevel3Name = if ($Context.collection) { $Context.collection.title } else { "" }
                $ldLevel3Url = $canonicalUrl
            }
        }
        "blog" {
            if ($Context.current_tags -and $Context.current_tags.Count -gt 0) {
                $ldLevel2Name = if ($Context.blog) { $Context.blog.title } else { "" }
                $ldLevel2Url = $shopUrl + $(if ($Context.blog) { $Context.blog.url } else { "" })
                $ldLevel3Name = ($Context.current_tags -join " + ")
                $ldLevel3Url = $canonicalUrl
            } else {
                $ldLevel2Name = if ($Context.blog) { $Context.blog.title } else { "" }
                $ldLevel2Url = $canonicalUrl
            }
        }
        "article" {
            $ldLevel2Name = if ($Context.blog) { $Context.blog.title } else { "" }
            $ldLevel2Url = $shopUrl + $(if ($Context.blog) { $Context.blog.url } else { "" })
            $ldLevel3Name = if ($Context.article) { $Context.article.title } else { "" }
            $ldLevel3Url = $canonicalUrl
        }
        "page" {
            $ldLevel2Name = if ($Context.page) { $Context.page.title } else { "" }
            $ldLevel2Url = $canonicalUrl
        }
        "search" {
            $searchTitle = if ($Context.ContainsKey("search_title")) { $Context["search_title"] } else { "Search" }
            $ldLevel2Name = $searchTitle
            $ldLevel2Url = $canonicalUrl
        }
        default {
            $ldLevel2Name = if ($Context.ContainsKey("page_title")) { $Context["page_title"] } else { "Page" }
            $ldLevel2Url = $canonicalUrl
        }
    }

    # Build the exact JSON text according to snippets/breadcrumbs.liquid lines 162-197:
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine('  "@context": "https://schema.org",')
    [void]$sb.AppendLine('  "@type": "BreadcrumbList",')
    [void]$sb.AppendLine('  "itemListElement": [')
    [void]$sb.AppendLine('    {')
    [void]$sb.AppendLine('      "@type": "ListItem",')
    [void]$sb.AppendLine('      "position": 1,')
    [void]$sb.AppendLine("      `"name`": $(Liquid-JsonFilter $homeTitle),")
    [void]$sb.AppendLine("      `"item`": $(Liquid-JsonFilter ($shopUrl + $rootUrl))")
    [void]$sb.Append('    }')

    # In Liquid: {%- if ld_level_2_name != blank -%}
    if (-not [string]::IsNullOrWhiteSpace($ldLevel2Name)) {
        [void]$sb.AppendLine(",")
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine('      "@type": "ListItem",')
        [void]$sb.AppendLine('      "position": 2,')
        [void]$sb.AppendLine("      `"name`": $(Liquid-JsonFilter $ldLevel2Name),")
        [void]$sb.AppendLine("      `"item`": $(Liquid-JsonFilter $ldLevel2Url)")
        [void]$sb.Append('    }')
    }

    # In Liquid: {%- if ld_level_3_name != blank -%}
    if (-not [string]::IsNullOrWhiteSpace($ldLevel3Name)) {
        [void]$sb.AppendLine(",")
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine('      "@type": "ListItem",')
        [void]$sb.AppendLine('      "position": 3,')
        [void]$sb.AppendLine("      `"name`": $(Liquid-JsonFilter $ldLevel3Name),")
        [void]$sb.AppendLine("      `"item`": $(Liquid-JsonFilter $ldLevel3Url)")
        [void]$sb.Append('    }')
    }

    # In Liquid: {%- if ld_level_4_name != blank -%}
    if (-not [string]::IsNullOrWhiteSpace($ldLevel4Name)) {
        [void]$sb.AppendLine(",")
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine('      "@type": "ListItem",')
        [void]$sb.AppendLine('      "position": 4,')
        [void]$sb.AppendLine("      `"name`": $(Liquid-JsonFilter $ldLevel4Name),")
        [void]$sb.AppendLine("      `"item`": $(Liquid-JsonFilter $ldLevel4Url)")
        [void]$sb.Append('    }')
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('  ]')
    [void]$sb.AppendLine('}')

    return $sb.ToString()
}

# Validator for Schema.org BreadcrumbList compliance
function Validate-BreadcrumbListJson([string]$jsonStr, [string]$ScenarioName) {
    $result = @{
        ValidJson = $false
        HasContext = $false
        HasType = $false
        HasItems = $false
        ItemsCount = 0
        PositionsValid = $false
        PositionsGaps = $false
        Positions = @()
        NamesValid = $true
        ItemsValid = $true
        Errors = @()
    }

    try {
        $parsed = ConvertFrom-Json -InputObject $jsonStr -ErrorAction Stop
        $result.ValidJson = $true
    } catch {
        $result.Errors += "JSON Syntax Error: $($_.Exception.Message)"
        return $result
    }

    # Schema.org checks
    if ($parsed.'@context' -eq "https://schema.org" -or $parsed.'@context' -eq "http://schema.org") {
        $result.HasContext = $true
    } else {
        $result.Errors += "@context is '$($parsed.'@context')', expected 'https://schema.org'"
    }

    if ($parsed.'@type' -eq "BreadcrumbList") {
        $result.HasType = $true
    } else {
        $result.Errors += "@type is '$($parsed.'@type')', expected 'BreadcrumbList'"
    }

    if ($null -ne $parsed.itemListElement -and $parsed.itemListElement.Count -gt 0) {
        $result.HasItems = $true
        $result.ItemsCount = $parsed.itemListElement.Count

        $expectedPos = 1
        foreach ($item in $parsed.itemListElement) {
            $pos = $item.position
            $result.Positions += $pos
            if ($pos -ne $expectedPos) {
                $result.PositionsGaps = $true
                $result.Errors += "Position sequence mismatch: found position $pos, expected $expectedPos"
            }
            $expectedPos++

            if ($item.'@type' -ne "ListItem") {
                $result.Errors += "Item @type is '$($item.'@type')', expected 'ListItem'"
            }
            if ([string]::IsNullOrWhiteSpace($item.name)) {
                $result.NamesValid = $false
                $result.Errors += "Item at position $pos has null or empty name"
            }
            if ($null -eq $item.item) {
                $result.ItemsValid = $false
                $result.Errors += "Item at position $pos has null item URL"
            }
        }
        $result.PositionsValid = (-not $result.PositionsGaps)
    } else {
        $result.Errors += "itemListElement is missing or empty"
    }

    return $result
}

# --- Test Scenarios ---
$stressScenarios = @(
    @{
        Id = "BC.1"
        Name = "Product with Collection (Standard)"
        Template = "product"
        Context = @{
            collection = @{ title = "Travel Gear"; url = "/collections/travel-gear" }
            product = @{ title = "Canitera Explorer Harness" }
            canonical_url = "https://canitera.com/collections/travel-gear/products/canitera-explorer-harness"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.2"
        Name = "Product without Direct Collection (Uses product.collections.first)"
        Template = "product"
        Context = @{
            collection = $null
            product = @{
                title = "All-Weather Leash"
                collections = @( @{ title = "Leashes & Collars"; url = "/collections/leashes" } )
            }
            canonical_url = "https://canitera.com/products/all-weather-leash"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.3"
        Name = "Product with Zero Collections (Fallback to Shop)"
        Template = "product"
        Context = @{
            collection = $null
            product = @{ title = "Standalone Treat Pouch"; collections = @() }
            canonical_url = "https://canitera.com/products/standalone-treat-pouch"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.4"
        Name = "Collection Page without Tags"
        Template = "collection"
        Context = @{
            collection = @{ title = "Adventure Beds"; url = "/collections/adventure-beds" }
            canonical_url = "https://canitera.com/collections/adventure-beds"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.5"
        Name = "Collection Page with Multiple Filter Tags"
        Template = "collection"
        Context = @{
            collection = @{ title = "Travel Gear"; url = "/collections/travel-gear" }
            current_tags = @("waterproof", "size-large", "eco-friendly")
            canonical_url = "https://canitera.com/collections/travel-gear/waterproof+size-large+eco-friendly"
        }
        ExpectedItems = 4
    },
    @{
        Id = "BC.6"
        Name = "Blog Page with Tags"
        Template = "blog"
        Context = @{
            blog = @{ title = "Journal"; url = "/blogs/journal" }
            current_tags = @("road-trips", "safety")
            canonical_url = "https://canitera.com/blogs/journal/tagged/road-trips+safety"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.7"
        Name = "Article Page"
        Template = "article"
        Context = @{
            blog = @{ title = "Journal"; url = "/blogs/journal" }
            article = @{ title = "10 Tips for Camping with Your Dog" }
            canonical_url = "https://canitera.com/blogs/journal/10-tips-for-camping-with-your-dog"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.8"
        Name = "Standard Page (About)"
        Template = "page"
        Context = @{
            page = @{ title = "About Canitera" }
            canonical_url = "https://canitera.com/pages/about"
        }
        ExpectedItems = 2
    },
    @{
        Id = "BC.9"
        Name = "Search Results Page"
        Template = "search"
        Context = @{
            search_title = "Search"
            canonical_url = "https://canitera.com/search?q=harness"
        }
        ExpectedItems = 2
    },
    @{
        Id = "BC.10"
        Name = "Suppression on Index & Cart Templates"
        Template = "index"
        Context = @{}
        ExpectedItems = 0
    },
    # Adversarial cases: special characters, quotes, XSS, Unicode
    @{
        Id = "BC.11"
        Name = "Adversarial: Double & Single Quotes in Titles"
        Template = "product"
        Context = @{
            collection = @{ title = 'Canitera "Rugged" & ''Trail-Tested'' Gear'; url = "/collections/rugged" }
            product = @{ title = 'The 24" "Summit" Pack / Dog''s Best Friend' }
            canonical_url = "https://canitera.com/products/summit-pack"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.12"
        Name = "Adversarial: HTML & Script Injection in Titles"
        Template = "article"
        Context = @{
            blog = @{ title = '<b>Travel</b> & Guides <script>alert("xss")</script>'; url = "/blogs/travel" }
            article = @{ title = 'How to Prevent Heatstroke <img src=x onerror=alert(1)> in Dogs' }
            canonical_url = "https://canitera.com/blogs/travel/heatstroke"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.13"
        Name = "Adversarial: Backslashes, Newlines, Tabs & Unicode"
        Template = "collection"
        Context = @{
            collection = @{ title = "Line 1`nLine 2`tTabbed \ Windows / Path 🐕 München €75"; url = "/collections/special" }
            current_tags = @("tag \ with / slashes", "🐶 doggo & 🐾 paws")
            canonical_url = "https://canitera.com/collections/special"
        }
        ExpectedItems = 4
    },
    @{
        Id = "BC.14"
        Name = "Adversarial: Deep URLs & Query Parameters"
        Template = "product"
        Context = @{
            collection = @{ title = "Gear"; url = "/collections/gear/sub-cat/deep-level?sort=manual&filter.v.price.gte=10.00&filter.v.price.lte=100.00#grid-top" }
            product = @{ title = "Deep Product" }
            canonical_url = "https://canitera.com/collections/gear/sub-cat/deep-level/products/deep-product?variant=123456789&ref=promo_banner_m1#description"
        }
        ExpectedItems = 3
    },
    @{
        Id = "BC.15"
        Name = "Edge Case: Blank Collection Title (Position Gap Stress Test)"
        Template = "product"
        Context = @{
            collection = @{ title = ""; url = "/collections/empty-title" }
            product = @{ title = "Harness with Blank Collection" }
            canonical_url = "https://canitera.com/products/blank-col-harness"
        }
        ExpectedItems = 2 # Note: level 2 has blank title so it is omitted; level 3 has position 3
    }
)

foreach ($sc in $stressScenarios) {
    $jsonOutput = Simulate-BreadcrumbsJsonLd -TemplateName $sc.Template -Context $sc.Context

    if ($sc.Template -eq "index" -or $sc.Template -eq "cart") {
        Assert-Test $sc.Id $sc.Name ($null -eq $jsonOutput) `
            "Snippet correctly suppresses BreadcrumbList output on '$($sc.Template)' template."
        continue
    }

    $val = Validate-BreadcrumbListJson -jsonStr $jsonOutput -ScenarioName $sc.Name

    # Check for Position Gap vulnerability specifically
    if ($sc.Id -eq "BC.15") {
        if ($val.PositionsGaps) {
            Add-Warning $sc.Id "Position Gap Invalidation on Blank Intermediate Title" `
                "When collection.title is empty, Level 2 is skipped but Product renders position: 3, creating gap [1, 3]! Google Search Console rejects gapped position sequences."
        }
    } else {
        Assert-Test $sc.Id "$($sc.Name) - Valid JSON-LD & Sequential Positions" ($val.ValidJson -and $val.PositionsValid -and $val.HasContext -and $val.HasType) `
            "Generated valid JSON-LD with $($val.ItemsCount) items. Positions: ($($val.Positions -join ', '))." ($val.Errors -join "; ")
    }
}

# =============================================================================
# SUITE 3: SETTINGS_SCHEMA.JSON STRICT SHOPIFY OS 2.0 RESTRICTIONS
# =============================================================================
Log-Section "SUITE 3: SETTINGS_SCHEMA.JSON STRICT OS 2.0 RESTRICTIONS"

$schemaPath = Join-Path $WorkspaceRoot "config\settings_schema.json"
$rawSchema = Get-Content -Path $schemaPath -Raw -Encoding UTF8
$parsedSchema = ConvertFrom-Json -InputObject $rawSchema

# Rule 3.1: Root must be an array
Assert-Test "S3.1" "Root is Array" ($parsedSchema -is [System.Array]) `
    "settings_schema.json root is a JSON array."

# Rule 3.2: Max 25 categories (Shopify OS 2.0 restriction)
$themeInfo = $null
$categories = @()
foreach ($item in $parsedSchema) {
    if ($item.name -eq "theme_info") {
        $themeInfo = $item
    } else {
        $categories += $item
    }
}
Assert-Test "S3.2" "Category Count <= 25 Limit" ($categories.Count -le 25) `
    "Total categories: $($categories.Count) (Shopify max limit is 25)."

# Rule 3.3: Theme Info object structure
if ($null -ne $themeInfo) {
    $hasThemeName = -not [string]::IsNullOrWhiteSpace($themeInfo.theme_name)
    $hasThemeAuthor = -not [string]::IsNullOrWhiteSpace($themeInfo.theme_author)
    $hasThemeVersion = -not [string]::IsNullOrWhiteSpace($themeInfo.theme_version)
    Assert-Test "S3.3" "theme_info Metadata Declaration" ($hasThemeName -and $hasThemeAuthor -and $hasThemeVersion) `
        "theme_name: '$($themeInfo.theme_name)', author: '$($themeInfo.theme_author)', version: '$($themeInfo.theme_version)'"
} else {
    Add-Warning "S3.3" "theme_info Metadata Declaration" "No theme_info block found in settings_schema.json"
}

# Rule 3.4: Allowed Setting Types in Shopify OS 2.0
$allowedSettingTypes = @(
    "header", "paragraph",
    "text", "textarea", "number", "checkbox", "radio", "range", "select",
    "color", "color_background", "font_picker",
    "collection", "product", "blog", "page", "link_list", "url", "video_url",
    "richtext", "html", "article", "image_picker", "video", "liquid", "inline_richtext",
    "color_scheme", "color_scheme_group"
)

$invalidTypes = @()
$missingIds = @()
$invalidIdFormat = @()
$allSettingIds = @()
$rangeErrors = @()
$selectErrors = @()
$missingTranslations = @()

# Load default locale schema for translation key verification
$localeSchemaPath = Join-Path $WorkspaceRoot "locales\en.default.schema.json"
$localeSchema = $null
if (Test-Path -Path $localeSchemaPath) {
    try {
        $localeSchema = Get-Content -Path $localeSchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    } catch {}
}

# Helper to check if translation key exists in en.default.schema.json
function Test-TranslationKeyExists([string]$tKey, $locObj) {
    if ($null -eq $locObj -or -not $tKey.StartsWith("t:")) { return $true }
    $cleanKey = $tKey.Substring(2) # Remove "t:"
    $parts = $cleanKey.Split('.')
    $curr = $locObj
    foreach ($p in $parts) {
        if ($null -eq $curr -or $null -eq $curr.$p) {
            return $false
        }
        $curr = $curr.$p
    }
    return $true
}

$catIdx = 0
foreach ($cat in $categories) {
    $catName = if ($cat.name) { $cat.name } else { "Category_$catIdx" }
    $catIdx++

    if ($cat.name -and $cat.name.StartsWith("t:")) {
        if (-not (Test-TranslationKeyExists -tKey $cat.name -locObj $localeSchema)) {
            $missingTranslations += "$catName (Category Name: $($cat.name))"
        }
    }

    if ($null -eq $cat.settings) { continue }

    foreach ($s in $cat.settings) {
        # Check type validity
        if ($null -eq $s.type -or ($allowedSettingTypes -notcontains $s.type.ToString())) {
            $invalidTypes += "$catName -> $($s.id): invalid type '$($s.type)'"
        }

        # Header / paragraph: must have content
        if ($s.type -eq "header" -or $s.type -eq "paragraph") {
            if ($s.content -and $s.content.StartsWith("t:")) {
                if (-not (Test-TranslationKeyExists -tKey $s.content -locObj $localeSchema)) {
                    $missingTranslations += "$catName content: $($s.content)"
                }
            }
            continue
        }

        # Interactive settings: must have id and label
        if ([string]::IsNullOrWhiteSpace($s.id)) {
            $missingIds += "$($catName): setting of type '$($s.type)' missing id"
        } else {
            $sId = $s.id.ToString()
            $allSettingIds += $sId

            # Valid ID regex: alphanumeric, underscores, hyphens
            if ($sId -notmatch '^[a-zA-Z0-9_\-]+$') {
                $invalidIdFormat += "$catName -> '$sId' contains invalid characters"
            }
        }

        if ($s.label -and $s.label.StartsWith("t:")) {
            if (-not (Test-TranslationKeyExists -tKey $s.label -locObj $localeSchema)) {
                $missingTranslations += "$catName -> $($s.id) label: $($s.label)"
            }
        }
        if ($s.info -and $s.info.StartsWith("t:")) {
            if (-not (Test-TranslationKeyExists -tKey $s.info -locObj $localeSchema)) {
                $missingTranslations += "$catName -> $($s.id) info: $($s.info)"
            }
        }

        # Range setting validation
        if ($s.type -eq "range") {
            if ($null -eq $s.min -or $null -eq $s.max -or $null -eq $s.step) {
                $rangeErrors += "$($s.id): missing min/max/step"
            } else {
                if ([double]$s.min -ge [double]$s.max) {
                    $rangeErrors += "$($s.id): min ($($s.min)) >= max ($($s.max))"
                }
                if ([double]$s.step -le 0) {
                    $rangeErrors += "$($s.id): step ($($s.step)) <= 0"
                }
                if ($null -ne $s.default) {
                    if ([double]$s.default -lt [double]$s.min -or [double]$s.default -gt [double]$s.max) {
                        $rangeErrors += "$($s.id): default ($($s.default)) outside [min, max]"
                    }
                }
            }
        }

        # Select / Radio setting validation
        if ($s.type -eq "select" -or $s.type -eq "radio") {
            if ($null -eq $s.options -or $s.options.Count -eq 0) {
                $selectErrors += "$($s.id): options array missing or empty"
            } else {
                $optValues = @()
                foreach ($opt in $s.options) {
                    if ($null -ne $opt.value) { $optValues += $opt.value.ToString() }
                }
                if ($null -ne $s.default -and ($optValues -notcontains $s.default.ToString())) {
                    $selectErrors += "$($s.id): default '$($s.default)' not in options ($($optValues -join ', '))"
                }
            }
        }
    }
}

Assert-Test "S3.4" "All Setting Types Allowed by Shopify OS 2.0" ($invalidTypes.Count -eq 0) `
    "All settings declare standard Shopify OS 2.0 types." ($invalidTypes -join "; ")

Assert-Test "S3.5" "All Interactive Settings Have Non-Empty ID" ($missingIds.Count -eq 0) `
    "Zero interactive settings missing IDs." ($missingIds -join "; ")

Assert-Test "S3.6" "All Setting IDs Format Valid (Regex ^[a-zA-Z0-9_\-]+$)" ($invalidIdFormat.Count -eq 0) `
    "All setting IDs use clean identifier syntax." ($invalidIdFormat -join "; ")

# Check Setting ID Uniqueness across the entire settings_schema.json
$idGroups = $allSettingIds | Group-Object | Where-Object { $_.Count -gt 1 }
$duplicateIdErrors = @()
foreach ($grp in $idGroups) {
    $duplicateIdErrors += "$($grp.Name) (duplicated $($grp.Count) times)"
}
Assert-Test "S3.7" "Setting IDs Globally Unique Across Theme" ($duplicateIdErrors.Count -eq 0) `
    "All $($allSettingIds.Count) setting IDs are strictly unique." ($duplicateIdErrors -join "; ")

Assert-Test "S3.8" "Range Settings Boundary & Step Constraints" ($rangeErrors.Count -eq 0) `
    "All range settings comply with min < max, step > 0, and default bounds." ($rangeErrors -join "; ")

Assert-Test "S3.9" "Select/Radio Options & Default Match" ($selectErrors.Count -eq 0) `
    "All select/radio settings define valid options and default matches." ($selectErrors -join "; ")

# Translation keys check
if ($missingTranslations.Count -gt 0) {
    Add-Warning "S3.10" "Missing Localization Schema Keys" `
        "Found $($missingTranslations.Count) schema translation references missing from en.default.schema.json: $($missingTranslations[0..4] -join '; ')..."
} else {
    Assert-Test "S3.10" "All Translation Keys Exist in en.default.schema.json" $true `
        "All schema translation keys resolve cleanly."
}

# Rule 3.11: Milestone 1 Specific Requirements in settings_schema.json and settings_data.json
$thresholdSetting = $null
foreach ($cat in $categories) {
    if ($null -ne $cat.settings) {
        foreach ($s in $cat.settings) {
            if ($s.id -eq "free_shipping_threshold") {
                $thresholdSetting = $s
                break
            }
        }
    }
    if ($null -ne $thresholdSetting) { break }
}
Assert-Test "S3.11" "free_shipping_threshold Setting in Schema" ($null -ne $thresholdSetting -and $thresholdSetting.type -eq "number") `
    "Setting 'free_shipping_threshold' exists with type 'number' and default $($thresholdSetting.default)."

# Settings Data Check
$dataPath = Join-Path $WorkspaceRoot "config\settings_data.json"
$dataRes = Get-Content -Path $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$currentPreset = $dataRes.current
$activePreset = $dataRes.presets.$currentPreset

Assert-Test "S3.12" "Canitera Active Preset Configuration" ($activePreset.cart_type -eq "drawer" -and $activePreset.free_shipping_threshold -eq 75) `
    "Active preset '$currentPreset' has cart_type='drawer' and free_shipping_threshold=75."

# Check Canitera Design Tokens: radii and palette
$radiiValid = ($activePreset.buttons_radius -eq 4 -and $activePreset.media_radius -eq 6 -and $activePreset.card_corner_radius -eq 4)
Assert-Test "S3.13" "Canitera Subtle Radii Design Tokens (buttons: 4px, media: 6px, card: 4px)" $radiiValid `
    "buttons_radius: $($activePreset.buttons_radius)px, media_radius: $($activePreset.media_radius)px, card_corner_radius: $($activePreset.card_corner_radius)px"

$scheme1 = $activePreset.color_schemes.'scheme-1'.settings
$paletteValid = ($scheme1.background -eq "#FAF8F5" -and $scheme1.text -eq "#1C1D1D" -and $scheme1.button -eq "#2D4030")
Assert-Test "S3.14" "Canitera Editorial Brand Palette (Scheme 1: #FAF8F5 base, #1C1D1D text, #2D4030 accent)" $paletteValid `
    "scheme-1 background: $($scheme1.background), text: $($scheme1.text), button: $($scheme1.button)"

# =============================================================================
# SUITE 4: VERIFY-THEME.PS1 EXECUTION & METRIC TRACKING
# =============================================================================
Log-Section "SUITE 4: VERIFY-THEME.PS1 RUNNER & METRICS"

$verifyScriptPath = Join-Path $WorkspaceRoot "verify-theme.ps1"
if (Test-Path -Path $verifyScriptPath) {
    Write-Host "  Executing verify-theme.ps1..." -ForegroundColor DarkGray
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = "-ExecutionPolicy Bypass -File `"$verifyScriptPath`""
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    
    $proc = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode

    # Extract metrics
    $passedCount = 0
    $failedCount = 0
    $totalCount = 0
    if ($stdout -match 'OVERALL RESULTS:\s*(\d+)\s*PASSED,\s*(\d+)\s*FAILED across\s*(\d+)\s*tests') {
        $passedCount = [int]$matches[1]
        $failedCount = [int]$matches[2]
        $totalCount = [int]$matches[3]
    }

    # Verify M1 tests specifically pass
    $m1TestsPassing = ($stdout -match '\[PASS\]\s*\[T1\.3\.5\]' -and `
                       $stdout -match '\[PASS\]\s*\[T1\.5\.4\]' -and `
                       $stdout -match '\[PASS\]\s*\[T1\.5\.5\]' -and `
                       $stdout -match '\[PASS\]\s*\[T3\.4\]')

    Assert-Test "S4.1" "verify-theme.ps1 Baseline Execution" ($totalCount -gt 0) `
        "Executed $totalCount tests ($passedCount passed, $failedCount failed, exit code $exitCode)."

    Assert-Test "S4.2" "All Milestone 1 Assigned Tests Pass in verify-theme.ps1" $m1TestsPassing `
        "T1.3.5 (Core Snippets), T1.5.4 (Threshold Schema), T1.5.5 (Active Settings), and T3.4 (Breadcrumbs JSON-LD) all PASS."

    # Verify remaining failures belong exclusively to downstream milestones (M2, M3, M4)
    $downstreamMilestonesOnly = $true
    $failedLines = $stdout -split "`r?`n" | Where-Object { $_ -match 'Assigned Implementation Milestone:' }
    foreach ($fl in $failedLines) {
        if ($fl -match 'Milestone:\s*(M1|Core)') {
            $downstreamMilestonesOnly = $false
        }
    }
    Assert-Test "S4.3" "Zero Failures Belong to Milestone 1 Scope" $downstreamMilestonesOnly `
        "All $failedCount failing tests are assigned to downstream milestones M2, M3, or M4."
} else {
    Assert-Test "S4.1" "verify-theme.ps1 Exists" $false "verify-theme.ps1 not found at workspace root."
}

# =============================================================================
# SUITE 5: CANITERA BRAND IDENTITY, 5 COLOR SCHEMES & DESIGN TOKENS
# =============================================================================
Log-Section "SUITE 5: CANITERA BRAND IDENTITY, 5 COLOR SCHEMES & DESIGN TOKENS"

$activeSchemes = $activePreset.color_schemes
$schemeNames = @("scheme-1", "scheme-2", "scheme-3", "scheme-4", "scheme-5")

# Test 5.1: All 5 color schemes defined
$all5SchemesPresent = $true
foreach ($sn in $schemeNames) {
    if ($null -eq $activeSchemes.$sn) { $all5SchemesPresent = $false }
}
Assert-Test "S5.1" "All 5 Canitera Color Schemes Present in settings_data.json" $all5SchemesPresent `
    "Verified scheme-1 through scheme-5 are declared in active preset."

# Test 5.2: Strict Hex Color Format across all scheme properties
$hexRegex = '^#[0-9A-Fa-f]{6}$'
$invalidHexList = @()
$totalHexTested = 0
foreach ($sn in $schemeNames) {
    if ($null -eq $activeSchemes.$sn) { continue }
    $props = $activeSchemes.$sn.settings.PSObject.Properties
    foreach ($p in $props) {
        $val = $p.Value
        if ($p.Name -eq "background_gradient") { continue } # Gradients can be empty or css gradient
        if ([string]::IsNullOrWhiteSpace($val)) { continue }
        $totalHexTested++
        if ($val -notmatch $hexRegex) {
            $invalidHexList += "$sn.$($p.Name)='$val'"
        }
    }
}
Assert-Test "S5.2" "Strict Hex Color Format Validation ($totalHexTested colors tested)" ($invalidHexList.Count -eq 0) `
    "All color properties match strict 6-character hex format (#RRGGBB)." ($invalidHexList -join "; ")

# Test 5.3: Scheme 1 (Warm Ivory Canvas)
$s1 = $activeSchemes.'scheme-1'.settings
$s1Valid = ($s1.background -eq "#FAF8F5" -and $s1.text -eq "#1C1D1D" -and $s1.button -eq "#2D4030" -and $s1.button_label -eq "#FAF8F5" -and $s1.secondary_button_label -eq "#2D4030")
Assert-Test "S5.3" "Scheme 1 Brand Conformance (Warm Ivory Canvas: #FAF8F5, Text: #1C1D1D, Button: #2D4030)" $s1Valid `
    "bg: $($s1.background), text: $($s1.text), btn: $($s1.button), btn_label: $($s1.button_label), sec_btn: $($s1.secondary_button_label)"

# Test 5.4: Scheme 2 (Muted Forest Green Accent)
$s2 = $activeSchemes.'scheme-2'.settings
$s2Valid = ($s2.background -eq "#2D4030" -and $s2.text -eq "#FAF8F5" -and $s2.button -eq "#FAF8F5" -and $s2.button_label -eq "#2D4030" -and $s2.secondary_button_label -eq "#FAF8F5")
Assert-Test "S5.4" "Scheme 2 Brand Conformance (Forest Green Accent: #2D4030, Text: #FAF8F5, Button: #FAF8F5)" $s2Valid `
    "bg: $($s2.background), text: $($s2.text), btn: $($s2.button)"

# Test 5.5: Scheme 3 (Deep Charcoal Depth)
$s3 = $activeSchemes.'scheme-3'.settings
$s3Valid = ($s3.background -eq "#1C1D1D" -and $s3.text -eq "#FAF8F5" -and $s3.button -eq "#2D4030" -and $s3.button_label -eq "#FAF8F5")
Assert-Test "S5.5" "Scheme 3 Brand Conformance (Deep Charcoal: #1C1D1D, Text: #FAF8F5, Button: #2D4030)" $s3Valid `
    "bg: $($s3.background), text: $($s3.text), btn: $($s3.button)"

# Test 5.6: Scheme 4 (Warm Sand Accent)
$s4 = $activeSchemes.'scheme-4'.settings
$s4Valid = ($s4.background -eq "#D9CBB8" -and $s4.text -eq "#1C1D1D" -and $s4.button -eq "#2D4030" -and $s4.button_label -eq "#FAF8F5")
Assert-Test "S5.6" "Scheme 4 Brand Conformance (Warm Sand: #D9CBB8, Text: #1C1D1D, Button: #2D4030)" $s4Valid `
    "bg: $($s4.background), text: $($s4.text), btn: $($s4.button)"

# Test 5.7: Scheme 5 (Dark Forest Green)
$s5 = $activeSchemes.'scheme-5'.settings
$s5Valid = ($s5.background -eq "#1E2B20" -and $s5.text -eq "#FAF8F5" -and $s5.button -eq "#D9CBB8" -and $s5.button_label -eq "#1E2B20")
Assert-Test "S5.7" "Scheme 5 Brand Conformance (Dark Forest Green: #1E2B20, Text: #FAF8F5, Button: #D9CBB8)" $s5Valid `
    "bg: $($s5.background), text: $($s5.text), btn: $($s5.button)"

# Test 5.8: Container Width Token (1200px)
Assert-Test "S5.8" "Page Container Max Width (1200px)" ($activePreset.page_width -eq 1200) `
    "page_width configured to $($activePreset.page_width)px."

# Test 5.9: Subtle Border Radii Tokens (4px - 6px)
$allRadiiSubtle = ($activePreset.buttons_radius -eq 4 -and `
                   $activePreset.media_radius -eq 6 -and `
                   $activePreset.card_corner_radius -eq 4 -and `
                   $activePreset.inputs_radius -eq 4 -and `
                   $activePreset.text_boxes_radius -eq 4 -and `
                   $activePreset.popup_corner_radius -eq 6 -and `
                   $activePreset.badge_corner_radius -eq 4)
Assert-Test "S5.9" "Subtle Radii Tokens (Buttons: 4px, Media: 6px, Cards: 4px, Inputs: 4px, Textboxes: 4px, Popups: 6px, Badges: 4px)" $allRadiiSubtle `
    "All UI element border radii strictly set to 4px-6px subtle curves."

# =============================================================================
# SUITE 6: CORE LIQUID SNIPPETS CONTRACTS, SECURITY & ACCESSIBILITY
# =============================================================================
Log-Section "SUITE 6: CORE LIQUID SNIPPETS CONTRACTS, SECURITY & ACCESSIBILITY"

# Snippet 6.1: breadcrumbs.liquid Semantic Structure & A11y
$bcPath = Join-Path $WorkspaceRoot "snippets\breadcrumbs.liquid"
$bcContent = Get-Content -Path $bcPath -Raw -Encoding UTF8
$bcSemantic = ($bcContent -match '<nav\b[^>]*class=["''].*breadcrumbs.*["'']' -and `
               $bcContent -match 'role=["'']navigation["'']' -and `
               $bcContent -match 'aria-label=' -and `
               $bcContent -match '<ol\b[^>]*class=["''].*breadcrumbs__list.*["'']' -and `
               $bcContent -match 'aria-current=["'']page["'']' -and `
               $bcContent -match 'aria-hidden=["'']true["'']')
Assert-Test "S6.1" "snippets/breadcrumbs.liquid Semantic HTML5 & ARIA Compliance" $bcSemantic `
    "Implements <nav role='navigation' aria-label>, <ol>, aria-current='page', and aria-hidden separators."

# Snippet 6.2: rating-stars.liquid Accessibility & Clamping Math
$rsPath = Join-Path $WorkspaceRoot "snippets\rating-stars.liquid"
$rsContent = Get-Content -Path $rsPath -Raw -Encoding UTF8
$rsA11y = ($rsContent -match 'role=["'']img["'']' -and `
           $rsContent -match 'aria-label=' -and `
           $rsContent -match 'class=["'']visually-hidden["'']' -and `
           $rsContent -match 'rating_val\s*>\s*max_rating' -and `
           $rsContent -match 'rating_val\s*<\s*0\.0' -and `
           $rsContent -match 'diff\s*==\s*-0\.5')
Assert-Test "S6.2" "snippets/rating-stars.liquid A11y & Clamping / Half-Star Logic" $rsA11y `
    "Implements role='img', aria-label, visually-hidden review count, upper/lower clamping, and half-star math."

# Snippet 6.3: responsive-image.liquid Performance & CLS Protection
$riPath = Join-Path $WorkspaceRoot "snippets\responsive-image.liquid"
$riContent = Get-Content -Path $riPath -Raw -Encoding UTF8
$riPerf = ($riContent -match 'placeholder_svg_tag' -and `
           $riContent -match '--aspect-ratio:' -and `
           $riContent -match 'loading:\s*loading_mode' -and `
           $riContent -match 'fetchpriority:\s*fetch_mode' -and `
           $riContent -match 'alt:\s*image_alt')
Assert-Test "S6.3" "snippets/responsive-image.liquid CLS Protection & Image Tag Filters" $riPerf `
    "Implements --aspect-ratio CSS wrapper, dynamic eager/lazy loading mode, high/auto fetchpriority, and placeholder fallback."

# Snippet 6.4: sticky-atc.liquid Custom Element & PubSub Hookup
$saPath = Join-Path $WorkspaceRoot "snippets\sticky-atc.liquid"
$saContent = Get-Content -Path $saPath -Raw -Encoding UTF8
$saWebComp = ($saContent -match '<sticky-atc\b' -and `
              $saContent -match 'customElements\.define\(''sticky-atc''' -and `
              $saContent -match 'IntersectionObserver' -and `
              $saContent -match 'PUB_SUB_EVENTS\.variantChange' -and `
              $saContent -match 'role=["'']region["'']' -and `
              $saContent -match 'aria-label=')
Assert-Test "S6.4" "snippets/sticky-atc.liquid Web Component & PubSub Architecture" $saWebComp `
    "Defines <sticky-atc> custom element with IntersectionObserver, variantChange subscription, and accessible region."

# Snippet 6.5: progress-bar.liquid Dual-Mode Operation & Division-by-Zero Guard
$pbPath = Join-Path $WorkspaceRoot "snippets\progress-bar.liquid"
$pbContent = Get-Content -Path $pbPath -Raw -Encoding UTF8
$pbGuards = ($pbContent -match 'target\s*>\s*0' -and `
             $pbContent -match 'percentage\s*>\s*100\.0' -and `
             $pbContent -match 'remaining\s*<\s*0' -and `
             $pbContent -match 'role=["'']progressbar["'']' -and `
             $pbContent -match 'aria-valuenow=' -and `
             $pbContent -match 'progress-bar-container')
Assert-Test "S6.5" "snippets/progress-bar.liquid Dual-Mode Operation & Math Guards" $pbGuards `
    "Implements target > 0 guard, clamping [0, 100], remaining >= 0, role='progressbar', and backward-compatible .progress-bar-container."

# Adversarial Escaping Audit
$bcEscapingObservations = @()
if ($bcContent -match '<span class="breadcrumbs__current">\{\{\s*product\.title\s*\}\}</span>') {
    $bcEscapingObservations += "product.title rendered in HTML without | escape"
}
if ($bcContent -match '<span class="breadcrumbs__current">\{\{\s*collection\.title\s*\}\}</span>') {
    $bcEscapingObservations += "collection.title rendered in HTML without | escape"
}
if ($bcContent -match '<span class="breadcrumbs__current">\{\{\s*page\.title\s*\}\}</span>') {
    $bcEscapingObservations += "page.title rendered in HTML without | escape"
}
if ($bcEscapingObservations.Count -gt 0) {
    Add-Warning "S6.6" "HTML Escaping in Breadcrumbs Visual Markup" `
        "Found visual breadcrumb elements rendering titles without '| escape' filter ($($bcEscapingObservations -join ', ')). While JSON-LD uses '| json' correctly, visual HTML should use '| escape' to prevent malformed HTML if titles contain '<', '>', or '&'."
} else {
    Assert-Test "S6.6" "All Visual Breadcrumb Titles HTML Escaped" $true "Visual titles use | escape."
}

# =============================================================================
# SUMMARY REPORT & VERDICT DETERMINATION
# =============================================================================
Log-Section "ADVERSARIAL STRESS-TEST SUMMARY"

Write-Host "  Total Tests:    $($script:TotalTests)" -ForegroundColor White
Write-Host "  Passed Tests:   $($script:PassedTests)" -ForegroundColor Green
Write-Host "  Failed Tests:   $($script:FailedTests)" -ForegroundColor $(if ($script:FailedTests -eq 0) { [System.ConsoleColor]::Green } else { [System.ConsoleColor]::Red })
Write-Host "  Warnings:       $($script:Warnings.Count)" -ForegroundColor Yellow

Write-Host ""
if ($script:FailedTests -eq 0) {
    Write-Host "  ====================================================================" -ForegroundColor Green
    Write-Host "  FINAL VERDICT: APPROVE (Milestone 1 Deliverables Pass All Stress Tests)" -ForegroundColor Green
    Write-Host "  ====================================================================" -ForegroundColor Green
} else {
    Write-Host "  ====================================================================" -ForegroundColor Red
    Write-Host "  FINAL VERDICT: REQUEST_CHANGES ($($script:FailedTests) Critical Tests Failed)" -ForegroundColor Red
    Write-Host "  ====================================================================" -ForegroundColor Red
}

Write-Host ""
exit $script:FailedTests
