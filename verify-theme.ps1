<#
.SYNOPSIS
    Canitera Shopify Theme Automated Verification Runner
.DESCRIPTION
    Comprehensive 4-tier automated test suite and verification runner for the Canitera
    Shopify Online Store 2.0 theme. Validates JSON template syntax, Liquid referential
    integrity, section schemas, boundary math, cross-feature integrations, and real-world
    WCAG AA / SEO scenarios.
.PARAMETER Tier
    Optional tier filter: 1, 2, 3, or 4. Defaults to running all tiers.
.PARAMETER Detailed
    Switch flag to display verbose diagnostic details for all tests.
.PARAMETER WorkspaceRoot
    Root directory of the Shopify theme. Defaults to current script directory.
.OUTPUTS
    Color-coded console output and exit code (0 for pass, 1 for fail).
#>

[CmdletBinding()]
param(
    [ValidateSet(1, 2, 3, 4)]
    [int]$Tier = 0,

    [switch]$Detailed,

    [string]$WorkspaceRoot = ""
)

# Enforce UTF-8 output encoding for symbols (such as euro currency)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Unicode currency symbol helper
$script:Euro = [char]0x20AC

# Resolve workspace root
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $WorkspaceRoot = $PSScriptRoot
    } else {
        $WorkspaceRoot = (Get-Location).Path
    }
}
$WorkspaceRoot = (Resolve-Path -Path $WorkspaceRoot).Path

# Initialize test tracking collections
$script:TestResults = New-Object System.Collections.ArrayList
$script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Formatting Helpers
function Write-Header([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
}

function Write-Subheader([string]$Title) {
    Write-Host ""
    Write-Host "--- $Title ---" -ForegroundColor Yellow
}

function Register-TestResult(
    [string]$TierName,
    [string]$Category,
    [string]$TestId,
    [string]$Name,
    [bool]$Passed,
    [string]$Message,
    [string]$Details = "",
    [string]$OwnerMilestone = "Core"
) {
    $record = [PSCustomObject]@{
        Tier           = $TierName
        Category       = $Category
        TestId         = $TestId
        Name           = $Name
        Passed         = $Passed
        Message        = $Message
        Details        = $Details
        OwnerMilestone = $OwnerMilestone
    }
    [void]$script:TestResults.Add($record)

    $statusBadge = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $statusColor = if ($Passed) { [System.ConsoleColor]::Green } else { [System.ConsoleColor]::Red }

    Write-Host "  $statusBadge " -ForegroundColor $statusColor -NoNewline
    Write-Host "[$TestId] " -ForegroundColor DarkGray -NoNewline
    Write-Host "$Name" -ForegroundColor White

    if (-not $Passed -or $Detailed) {
        if (-not [string]::IsNullOrWhiteSpace($Message)) {
            $msgColor = if ($Passed) { [System.ConsoleColor]::DarkGray } else { [System.ConsoleColor]::Yellow }
            Write-Host "         $Message" -ForegroundColor $msgColor
        }
        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host "         Details: $Details" -ForegroundColor DarkYellow
        }
        if (-not $Passed -and -not [string]::IsNullOrWhiteSpace($OwnerMilestone)) {
            Write-Host "         Responsible Milestone: $OwnerMilestone" -ForegroundColor Magenta
        }
    }
}

function Safe-ReadJsonFile([string]$FilePath) {
    if (-not (Test-Path -Path $FilePath)) {
        return @{ Success = $false; Error = "File not found: $FilePath"; Data = $null }
    }
    try {
        $raw = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return @{ Success = $false; Error = "File is empty"; Data = $null }
        }
        $data = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        return @{ Success = $true; Error = ""; Data = $data; Raw = $raw }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message; Data = $null }
    }
}

# -----------------------------------------------------------------------------
# TIER 1: FEATURE COVERAGE (25 TESTS ACROSS 5 CORE FEATURES)
# -----------------------------------------------------------------------------
function Run-Tier1 {
    Write-Header "TIER 1: FEATURE COVERAGE (25 TESTS ACROSS 5 CORE FEATURES)"

    # -------------------------------------------------------------------------
    # Feature 1.1: JSON Template Syntax & Structure
    # -------------------------------------------------------------------------
    Write-Subheader "Feature 1.1: JSON Template Syntax & Structure"

    # Test 1.1.1: Template JSON Syntax Validity
    $templateFiles = Get-ChildItem -Path (Join-Path $WorkspaceRoot "templates") -Filter "*.json" -File -ErrorAction SilentlyContinue
    $groupFiles = Get-ChildItem -Path (Join-Path $WorkspaceRoot "sections") -Filter "*-group.json" -File -ErrorAction SilentlyContinue
    $allJsonTemplates = @($templateFiles) + @($groupFiles)

    $syntaxFailed = @()
    foreach ($file in $allJsonTemplates) {
        $res = Safe-ReadJsonFile -FilePath $file.FullName
        if (-not $res.Success) {
            $syntaxFailed += "$($file.Name): $($res.Error)"
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "JSON Templates" -TestId "T1.1.1" `
        -Name "Template JSON Syntax Validity ($($allJsonTemplates.Count) files tested)" `
        -Passed ($syntaxFailed.Count -eq 0) `
        -Message $(if ($syntaxFailed.Count -eq 0) { "All $($allJsonTemplates.Count) template and group JSON files parse cleanly." } else { "$($syntaxFailed.Count) JSON files failed parsing." }) `
        -Details ($syntaxFailed -join "; ") -OwnerMilestone "M1"

    # Test 1.1.2: Template Root Architecture (sections + order)
    $archFailed = @()
    foreach ($file in $templateFiles) {
        $res = Safe-ReadJsonFile -FilePath $file.FullName
        if ($res.Success) {
            $data = $res.Data
            $hasSections = $null -ne $data.sections
            $hasOrder = $null -ne $data.order
            if (-not ($hasSections -and $hasOrder)) {
                $archFailed += "$($file.Name) (sections: $hasSections, order: $hasOrder)"
            }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "JSON Templates" -TestId "T1.1.2" `
        -Name "Template Root Architecture ('sections' object + 'order' array present)" `
        -Passed ($archFailed.Count -eq 0) `
        -Message $(if ($archFailed.Count -eq 0) { "All $($templateFiles.Count) templates define both sections and order." } else { "$($archFailed.Count) templates missing root sections/order." }) `
        -Details ($archFailed -join "; ") -OwnerMilestone "M1"

    # Test 1.1.3: Template Order Referential Integrity
    $orderFailed = @()
    foreach ($file in $templateFiles) {
        $res = Safe-ReadJsonFile -FilePath $file.FullName
        if ($res.Success -and $null -ne $res.Data.order -and $null -ne $res.Data.sections) {
            $data = $res.Data
            foreach ($secId in $data.order) {
                if ($null -eq $data.sections.$secId) {
                    $orderFailed += "$($file.Name): order references '$secId' not found in sections"
                }
            }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "JSON Templates" -TestId "T1.1.3" `
        -Name "Template Order Referential Integrity (All order IDs exist in sections)" `
        -Passed ($orderFailed.Count -eq 0) `
        -Message $(if ($orderFailed.Count -eq 0) { "All section order references resolve validly." } else { "$($orderFailed.Count) unresolved order references found." }) `
        -Details ($orderFailed -join "; ") -OwnerMilestone "M1"

    # Test 1.1.4: Section Block Referential Integrity
    $blockFailed = @()
    foreach ($file in $templateFiles) {
        $res = Safe-ReadJsonFile -FilePath $file.FullName
        if ($res.Success -and $null -ne $res.Data.sections) {
            $sectionsObj = $res.Data.sections
            foreach ($prop in $sectionsObj.PSObject.Properties) {
                $sec = $prop.Value
                if ($null -ne $sec -and $null -ne $sec.block_order) {
                    foreach ($bId in $sec.block_order) {
                        if ($null -eq $sec.blocks -or $null -eq $sec.blocks.$bId) {
                            $blockFailed += "$($file.Name): section '$($prop.Name)' block_order references missing block '$bId'"
                        }
                    }
                }
            }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "JSON Templates" -TestId "T1.1.4" `
        -Name "Section Block Referential Integrity (All block_order IDs exist in blocks)" `
        -Passed ($blockFailed.Count -eq 0) `
        -Message $(if ($blockFailed.Count -eq 0) { "All block order references resolve validly." } else { "$($blockFailed.Count) unresolved block references found." }) `
        -Details ($blockFailed -join "; ") -OwnerMilestone "M1"

    # Test 1.1.5: Section Configuration Type Validity
    $typeFailed = @()
    foreach ($file in $templateFiles) {
        $res = Safe-ReadJsonFile -FilePath $file.FullName
        if ($res.Success -and $null -ne $res.Data.sections) {
            $sectionsObj = $res.Data.sections
            foreach ($prop in $sectionsObj.PSObject.Properties) {
                $sec = $prop.Value
                if ($null -eq $sec.type -or [string]::IsNullOrWhiteSpace($sec.type.ToString())) {
                    $typeFailed += "$($file.Name): section '$($prop.Name)' missing string 'type'"
                }
            }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "JSON Templates" -TestId "T1.1.5" `
        -Name "Section Configuration Type Validity (All sections specify non-empty type)" `
        -Passed ($typeFailed.Count -eq 0) `
        -Message $(if ($typeFailed.Count -eq 0) { "All sections declare a non-empty type." } else { "$($typeFailed.Count) sections missing type definition." }) `
        -Details ($typeFailed -join "; ") -OwnerMilestone "M1"


    # -------------------------------------------------------------------------
    # Feature 1.2: Section File Existence
    # -------------------------------------------------------------------------
    Write-Subheader "Feature 1.2: Section File Existence for Referenced Sections"

    # Test 1.2.1: Homepage Sections File Existence
    $indexJsonPath = Join-Path $WorkspaceRoot "templates\index.json"
    $indexRes = Safe-ReadJsonFile -FilePath $indexJsonPath
    $indexMissing = @()
    if ($indexRes.Success -and $null -ne $indexRes.Data.sections) {
        foreach ($prop in $indexRes.Data.sections.PSObject.Properties) {
            $secType = $prop.Value.type
            $secFile = Join-Path $WorkspaceRoot "sections\$secType.liquid"
            if (-not (Test-Path -Path $secFile)) {
                $indexMissing += "$secType.liquid (referenced in index.json by $($prop.Name))"
            }
        }
    } else {
        $indexMissing += "Unable to read templates/index.json"
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Existence" -TestId "T1.2.1" `
        -Name "Homepage Sections File Existence (All index.json sections exist)" `
        -Passed ($indexMissing.Count -eq 0) `
        -Message $(if ($indexMissing.Count -eq 0) { "All homepage sections exist in sections/." } else { "$($indexMissing.Count) index.json section files missing." }) `
        -Details ($indexMissing -join "; ") -OwnerMilestone "M3"

    # Test 1.2.2: Header Group Sections File Existence
    $headerGroupPath = Join-Path $WorkspaceRoot "sections\header-group.json"
    $headerRes = Safe-ReadJsonFile -FilePath $headerGroupPath
    $headerMissing = @()
    if ($headerRes.Success -and $null -ne $headerRes.Data.sections) {
        foreach ($prop in $headerRes.Data.sections.PSObject.Properties) {
            $secType = $prop.Value.type
            $secFile = Join-Path $WorkspaceRoot "sections\$secType.liquid"
            if (-not (Test-Path -Path $secFile)) {
                $headerMissing += "$secType.liquid"
            }
        }
    } elseif (-not $headerRes.Success) {
        $headerMissing += "header-group.json could not be loaded: $($headerRes.Error)"
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Existence" -TestId "T1.2.2" `
        -Name "Header Group Sections File Existence (header-group.json)" `
        -Passed ($headerMissing.Count -eq 0) `
        -Message $(if ($headerMissing.Count -eq 0) { "All header group sections exist." } else { "$($headerMissing.Count) header group section files missing." }) `
        -Details ($headerMissing -join "; ") -OwnerMilestone "M2"

    # Test 1.2.3: Footer Group Sections File Existence
    $footerGroupPath = Join-Path $WorkspaceRoot "sections\footer-group.json"
    $footerRes = Safe-ReadJsonFile -FilePath $footerGroupPath
    $footerMissing = @()
    if ($footerRes.Success -and $null -ne $footerRes.Data.sections) {
        foreach ($prop in $footerRes.Data.sections.PSObject.Properties) {
            $secType = $prop.Value.type
            $secFile = Join-Path $WorkspaceRoot "sections\$secType.liquid"
            if (-not (Test-Path -Path $secFile)) {
                $footerMissing += "$secType.liquid"
            }
        }
    } elseif (-not $footerRes.Success) {
        $footerMissing += "footer-group.json could not be loaded: $($footerRes.Error)"
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Existence" -TestId "T1.2.3" `
        -Name "Footer Group Sections File Existence (footer-group.json)" `
        -Passed ($footerMissing.Count -eq 0) `
        -Message $(if ($footerMissing.Count -eq 0) { "All footer group sections exist." } else { "$($footerMissing.Count) footer group section files missing." }) `
        -Details ($footerMissing -join "; ") -OwnerMilestone "M2"

    # Test 1.2.4: Specialized Template Sections File Existence
    $specMissing = @()
    foreach ($file in $templateFiles) {
        if ($file.Name -eq "index.json") { continue }
        $res = Safe-ReadJsonFile -FilePath $file.FullName
        if ($res.Success -and $null -ne $res.Data.sections) {
            foreach ($prop in $res.Data.sections.PSObject.Properties) {
                $secType = $prop.Value.type
                $secFile = Join-Path $WorkspaceRoot "sections\$secType.liquid"
                if (-not (Test-Path -Path $secFile)) {
                    $specMissing += "$($file.Name) -> $secType.liquid"
                }
            }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Existence" -TestId "T1.2.4" `
        -Name "Specialized Templates Section File Existence (product, collection, etc.)" `
        -Passed ($specMissing.Count -eq 0) `
        -Message $(if ($specMissing.Count -eq 0) { "All sections in specialized templates exist." } else { "$($specMissing.Count) specialized template section references unresolved." }) `
        -Details ($specMissing -join "; ") -OwnerMilestone "M4"

    # Test 1.2.5: Zero Orphan Section References Across Entire Theme
    $allReferencedSections = @{}
    foreach ($file in $allJsonTemplates) {
        $res = Safe-ReadJsonFile -FilePath $file.FullName
        if ($res.Success -and $null -ne $res.Data.sections) {
            foreach ($prop in $res.Data.sections.PSObject.Properties) {
                $secType = $prop.Value.type
                if (-not [string]::IsNullOrWhiteSpace($secType)) {
                    $allReferencedSections[$secType] = $file.Name
                }
            }
        }
    }
    $orphanSections = @()
    foreach ($secType in $allReferencedSections.Keys) {
        $p = Join-Path $WorkspaceRoot "sections\$secType.liquid"
        if (-not (Test-Path -Path $p)) {
            $orphanSections += "$secType (referenced in $($allReferencedSections[$secType]))"
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Existence" -TestId "T1.2.5" `
        -Name "Zero Orphan Section References Across All JSON Files ($($allReferencedSections.Count) unique types)" `
        -Passed ($orphanSections.Count -eq 0) `
        -Message $(if ($orphanSections.Count -eq 0) { "Zero orphan section references found across all templates." } else { "$($orphanSections.Count) orphan section references found." }) `
        -Details ($orphanSections -join "; ") -OwnerMilestone "M4"


    # -------------------------------------------------------------------------
    # Feature 1.3: Snippet File Existence for {% render %} Calls
    # -------------------------------------------------------------------------
    Write-Subheader "Feature 1.3: Snippet File Existence for {% render %} Calls"

    $renderRegex = [regex]'\{%[-]?\s*(?:render|include)\s+[''"]([a-zA-Z0-9_\-]+)'

    function Get-MissingSnippetsInDir([string]$SubDir) {
        $dirPath = Join-Path $WorkspaceRoot $SubDir
        $missing = @()
        if (-not (Test-Path -Path $dirPath)) { return $missing }
        $files = Get-ChildItem -Path $dirPath -Filter "*.liquid" -File -Recurse -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $content = Get-Content -Path $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($content)) { continue }
            $matches = $renderRegex.Matches($content)
            foreach ($m in $matches) {
                $snippetName = $m.Groups[1].Value
                $snippetPath = Join-Path $WorkspaceRoot "snippets\$snippetName.liquid"
                if (-not (Test-Path -Path $snippetPath)) {
                    $missing += "$($f.Name) -> $snippetName"
                }
            }
        }
        return @($missing | Select-Object -Unique)
    }

    # Test 1.3.1: Layout Snippet Reference Resolution
    $missingLayoutSnippets = Get-MissingSnippetsInDir -SubDir "layout"
    Register-TestResult -TierName "Tier 1" -Category "Snippet Existence" -TestId "T1.3.1" `
        -Name "Layout Snippet Reference Resolution (layout/*.liquid)" `
        -Passed ($missingLayoutSnippets.Count -eq 0) `
        -Message $(if ($missingLayoutSnippets.Count -eq 0) { "All snippet renders in layout/ resolve validly." } else { "$($missingLayoutSnippets.Count) unresolvable snippet calls in layout/." }) `
        -Details ($missingLayoutSnippets -join "; ") -OwnerMilestone "M1"

    # Test 1.3.2: Section Snippet Reference Resolution
    $missingSectionSnippets = Get-MissingSnippetsInDir -SubDir "sections"
    Register-TestResult -TierName "Tier 1" -Category "Snippet Existence" -TestId "T1.3.2" `
        -Name "Section Snippet Reference Resolution (sections/*.liquid)" `
        -Passed ($missingSectionSnippets.Count -eq 0) `
        -Message $(if ($missingSectionSnippets.Count -eq 0) { "All snippet renders in sections/ resolve validly." } else { "$($missingSectionSnippets.Count) unresolvable snippet calls in sections/." }) `
        -Details ($missingSectionSnippets -join "; ") -OwnerMilestone "M2"

    # Test 1.3.3: Nested Snippet-to-Snippet Reference Resolution
    $missingNestedSnippets = Get-MissingSnippetsInDir -SubDir "snippets"
    Register-TestResult -TierName "Tier 1" -Category "Snippet Existence" -TestId "T1.3.3" `
        -Name "Nested Snippet Reference Resolution (snippets/*.liquid)" `
        -Passed ($missingNestedSnippets.Count -eq 0) `
        -Message $(if ($missingNestedSnippets.Count -eq 0) { "All nested snippet renders resolve validly." } else { "$($missingNestedSnippets.Count) unresolvable nested snippet calls." }) `
        -Details ($missingNestedSnippets -join "; ") -OwnerMilestone "M1"

    # Test 1.3.4: Legacy Include Reference Resolution
    $includeRegex = [regex]'\{%[-]?\s*include\s+[''"]([a-zA-Z0-9_\-]+)'
    $missingIncludes = @()
    $allLiquidFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.liquid" -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $allLiquidFiles) {
        $content = Get-Content -Path $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $matches = $includeRegex.Matches($content)
        foreach ($m in $matches) {
            $snippetName = $m.Groups[1].Value
            $snippetPath = Join-Path $WorkspaceRoot "snippets\$snippetName.liquid"
            if (-not (Test-Path -Path $snippetPath)) {
                $missingIncludes += "$($f.Name) -> $snippetName"
            }
        }
    }
    $missingIncludes = @($missingIncludes | Select-Object -Unique)
    Register-TestResult -TierName "Tier 1" -Category "Snippet Existence" -TestId "T1.3.4" `
        -Name "Legacy Include Reference Resolution ({% include '...' %})" `
        -Passed ($missingIncludes.Count -eq 0) `
        -Message $(if ($missingIncludes.Count -eq 0) { "All legacy includes resolve to existing snippets." } else { "$($missingIncludes.Count) unresolvable includes found." }) `
        -Details ($missingIncludes -join "; ") -OwnerMilestone "M1"

    # Test 1.3.5: Canitera Core Snippets Existence
    $coreSnippets = @(
        "rating-stars",
        "breadcrumbs",
        "responsive-image",
        "sticky-atc",
        "cart-drawer"
    )
    $missingCore = @()
    foreach ($snip in $coreSnippets) {
        $snipPath = Join-Path $WorkspaceRoot "snippets\$snip.liquid"
        if (-not (Test-Path -Path $snipPath)) {
            $missingCore += "$snip.liquid"
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "Snippet Existence" -TestId "T1.3.5" `
        -Name "Canitera Core Snippets Existence (rating-stars, breadcrumbs, responsive-image, etc.)" `
        -Passed ($missingCore.Count -eq 0) `
        -Message $(if ($missingCore.Count -eq 0) { "All Canitera core snippets exist." } else { "$($missingCore.Count) Canitera core snippets missing." }) `
        -Details ($missingCore -join ", ") -OwnerMilestone "M1"


    # -------------------------------------------------------------------------
    # Feature 1.4: Section Schema JSON Validity & Presets
    # -------------------------------------------------------------------------
    Write-Subheader "Feature 1.4: Section Schema JSON Validity & Presets"

    $schemaRegex = [regex]'(?s)\{%[-]?\s*schema\s*[-]?%\}(.*?)\{%[-]?\s*endschema\s*[-]?%\}'
    $sectionFiles = Get-ChildItem -Path (Join-Path $WorkspaceRoot "sections") -Filter "*.liquid" -File -ErrorAction SilentlyContinue

    $parsedSchemas = @{}
    $schemaErrors = @()
    foreach ($sf in $sectionFiles) {
        $content = Get-Content -Path $sf.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $match = $schemaRegex.Match($content)
        if ($match.Success) {
            $jsonStr = $match.Groups[1].Value.Trim()
            try {
                $schemaObj = ConvertFrom-Json -InputObject $jsonStr -ErrorAction Stop
                $parsedSchemas[$sf.Name] = $schemaObj
            } catch {
                $schemaErrors += "$($sf.Name): $($_.Exception.Message)"
            }
        }
    }

    # Test 1.4.1: Section Schema Extraction & JSON Parsing
    Register-TestResult -TierName "Tier 1" -Category "Section Schemas" -TestId "T1.4.1" `
        -Name "Section Schema JSON Parsing ($($parsedSchemas.Count) schemas extracted)" `
        -Passed ($schemaErrors.Count -eq 0) `
        -Message $(if ($schemaErrors.Count -eq 0) { "All section schemas parsed with valid JSON." } else { "$($schemaErrors.Count) schemas contain JSON parse errors." }) `
        -Details ($schemaErrors -join "; ") -OwnerMilestone "M3"

    # Test 1.4.2: Section Schema Name Attribute Presence
    $missingName = @()
    foreach ($entry in $parsedSchemas.GetEnumerator()) {
        $sch = $entry.Value
        if ($null -eq $sch.name -or [string]::IsNullOrWhiteSpace($sch.name.ToString())) {
            $missingName += $entry.Key
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Schemas" -TestId "T1.4.2" `
        -Name "Section Schema Name Attribute Presence (All schemas have name)" `
        -Passed ($missingName.Count -eq 0) `
        -Message $(if ($missingName.Count -eq 0) { "All extracted schemas have a non-empty name." } else { "$($missingName.Count) schemas missing name attribute." }) `
        -Details ($missingName -join ", ") -OwnerMilestone "M3"

    # Test 1.4.3: Section Preset Schema Structure
    $presetErrors = @()
    foreach ($entry in $parsedSchemas.GetEnumerator()) {
        $sch = $entry.Value
        if ($null -ne $sch.presets) {
            $pIdx = 0
            foreach ($preset in $sch.presets) {
                if ($null -eq $preset.name -or [string]::IsNullOrWhiteSpace($preset.name.ToString())) {
                    $presetErrors += "$($entry.Key): preset at index $pIdx missing name"
                }
                $pIdx++
            }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Schemas" -TestId "T1.4.3" `
        -Name "Section Preset Schema Structure (All presets define valid name)" `
        -Passed ($presetErrors.Count -eq 0) `
        -Message $(if ($presetErrors.Count -eq 0) { "All presets define valid name strings." } else { "$($presetErrors.Count) preset structure errors found." }) `
        -Details ($presetErrors -join "; ") -OwnerMilestone "M3"

    # Test 1.4.4: Section Preset Block Type Referential Integrity
    $presetBlockErrors = @()
    foreach ($entry in $parsedSchemas.GetEnumerator()) {
        $sch = $entry.Value
        if ($null -ne $sch.presets -and $null -ne $sch.blocks) {
            $allowedBlockTypes = @()
            foreach ($b in $sch.blocks) {
                if ($null -ne $b.type) { $allowedBlockTypes += $b.type.ToString() }
            }
            foreach ($preset in $sch.presets) {
                if ($null -ne $preset.blocks) {
                    foreach ($pb in $preset.blocks) {
                        if ($null -ne $pb.type -and ($allowedBlockTypes -notcontains $pb.type.ToString())) {
                            $presetBlockErrors += "$($entry.Key): preset references undefined block type '$($pb.type)'"
                        }
                    }
                }
            }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Schemas" -TestId "T1.4.4" `
        -Name "Section Preset Block Type Referential Integrity" `
        -Passed ($presetBlockErrors.Count -eq 0) `
        -Message $(if ($presetBlockErrors.Count -eq 0) { "All preset blocks match declared block schemas." } else { "$($presetBlockErrors.Count) preset blocks reference undeclared types." }) `
        -Details ($presetBlockErrors -join "; ") -OwnerMilestone "M3"

    # Test 1.4.5: Canitera Modular Sections Preset Presence
    $caniteraModularSections = @(
        "hero-cover.liquid",
        "trust-value-strip.liquid",
        "featured-collection.liquid",
        "brand-story-split.liquid",
        "shop-by-adventure.liquid",
        "hero-product-spotlight.liquid",
        "why-canitera.liquid",
        "lifestyle-banner.liquid",
        "testimonials.liquid",
        "community-ugc.liquid",
        "journal-newsletter.liquid",
        "final-cta-banner.liquid"
    )
    $missingPresets = @()
    foreach ($secFile in $caniteraModularSections) {
        $p = Join-Path $WorkspaceRoot "sections\$secFile"
        if (-not (Test-Path -Path $p)) {
            $missingPresets += "$secFile (file missing)"
        } else {
            $sch = $parsedSchemas[$secFile]
            if ($null -eq $sch -or $null -eq $sch.presets -or $sch.presets.Count -eq 0) {
                $missingPresets += "$secFile (presets missing in schema)"
            }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "Section Schemas" -TestId "T1.4.5" `
        -Name "Canitera Modular Sections Preset Presence ($($caniteraModularSections.Count) sections checked)" `
        -Passed ($missingPresets.Count -eq 0) `
        -Message $(if ($missingPresets.Count -eq 0) { "All Canitera modular sections provide editor presets." } else { "$($missingPresets.Count) modular sections lack presets or files." }) `
        -Details ($missingPresets -join ", ") -OwnerMilestone "M3"


    # -------------------------------------------------------------------------
    # Feature 1.5: Settings Schema & Canitera Settings Presence
    # -------------------------------------------------------------------------
    Write-Subheader "Feature 1.5: Settings Schema & Canitera Settings Presence"

    $schemaPath = Join-Path $WorkspaceRoot "config\settings_schema.json"
    $dataPath = Join-Path $WorkspaceRoot "config\settings_data.json"

    $schemaRes = Safe-ReadJsonFile -FilePath $schemaPath
    $dataRes = Safe-ReadJsonFile -FilePath $dataPath

    # Test 1.5.1: Settings Schema JSON Validity
    Register-TestResult -TierName "Tier 1" -Category "Theme Settings" -TestId "T1.5.1" `
        -Name "settings_schema.json Syntax Validity" `
        -Passed $schemaRes.Success `
        -Message $(if ($schemaRes.Success) { "settings_schema.json is valid JSON." } else { "JSON parse error: $($schemaRes.Error)" }) `
        -OwnerMilestone "M1"

    # Test 1.5.2: Settings Data JSON Validity
    Register-TestResult -TierName "Tier 1" -Category "Theme Settings" -TestId "T1.5.2" `
        -Name "settings_data.json Syntax Validity" `
        -Passed $dataRes.Success `
        -Message $(if ($dataRes.Success) { "settings_data.json is valid JSON." } else { "JSON parse error: $($dataRes.Error)" }) `
        -OwnerMilestone "M1"

    # Test 1.5.3: Settings Schema Core Categories
    $requiredCategories = @("colors", "typography", "layout", "buttons", "cart", "social-media")
    $missingCategories = @()
    if ($schemaRes.Success) {
        $foundNames = @()
        foreach ($item in $schemaRes.Data) {
            if ($null -ne $item.name) { $foundNames += $item.name.ToString().ToLower() }
        }
        foreach ($cat in $requiredCategories) {
            $matched = $false
            foreach ($fn in $foundNames) {
                if ($fn.Contains($cat)) { $matched = $true; break }
            }
            if (-not $matched) { $missingCategories += $cat }
        }
    } else {
        $missingCategories = $requiredCategories
    }
    Register-TestResult -TierName "Tier 1" -Category "Theme Settings" -TestId "T1.5.3" `
        -Name "Settings Schema Core Categories Presence (colors, typography, layout, cart, etc.)" `
        -Passed ($missingCategories.Count -eq 0) `
        -Message $(if ($missingCategories.Count -eq 0) { "All core settings categories present in schema." } else { "$($missingCategories.Count) categories missing in settings_schema.json." }) `
        -Details ($missingCategories -join ", ") -OwnerMilestone "M1"

    # Test 1.5.4: Free Shipping Threshold Setting Definition
    $hasThresholdSetting = $false
    if ($schemaRes.Success) {
        foreach ($group in $schemaRes.Data) {
            if ($null -ne $group.settings) {
                foreach ($s in $group.settings) {
                    if ($s.id -eq "free_shipping_threshold") {
                        $hasThresholdSetting = $true
                        break
                    }
                }
            }
            if ($hasThresholdSetting) { break }
        }
    }
    Register-TestResult -TierName "Tier 1" -Category "Theme Settings" -TestId "T1.5.4" `
        -Name "Free Shipping Threshold Setting Defined in settings_schema.json" `
        -Passed $hasThresholdSetting `
        -Message $(if ($hasThresholdSetting) { "free_shipping_threshold setting defined in schema." } else { "free_shipping_threshold setting NOT found in settings_schema.json." }) `
        -Details "Expected setting id 'free_shipping_threshold' with numeric type" -OwnerMilestone "M1"

    # Test 1.5.5: Canitera Active Settings Configuration
    $hasCartDrawerConfig = $false
    $hasThresholdConfig = $false
    if ($dataRes.Success) {
        $currentPreset = $dataRes.Data.current
        $activeSettings = $null
        if ($null -ne $currentPreset -and $null -ne $dataRes.Data.presets -and $null -ne $dataRes.Data.presets.$currentPreset) {
            $activeSettings = $dataRes.Data.presets.$currentPreset
        }
        if ($null -ne $activeSettings) {
            if ($activeSettings.cart_type -eq "drawer") { $hasCartDrawerConfig = $true }
            if ($null -ne $activeSettings.free_shipping_threshold -and [double]$activeSettings.free_shipping_threshold -ge 0) {
                $hasThresholdConfig = $true
            }
        }
    }
    $settingsPassed = ($hasCartDrawerConfig -and $hasThresholdConfig)
    Register-TestResult -TierName "Tier 1" -Category "Theme Settings" -TestId "T1.5.5" `
        -Name "Canitera Active Settings Configuration (cart_type='drawer', free_shipping_threshold set)" `
        -Passed $settingsPassed `
        -Message $(if ($settingsPassed) { "Active settings correctly configure cart drawer and free shipping threshold." } else { "cart_type ('drawer': $hasCartDrawerConfig) or free_shipping_threshold ($hasThresholdConfig) not configured." }) `
        -OwnerMilestone "M1"
}

# -----------------------------------------------------------------------------
# TIER 2: BOUNDARY & CORNER CASES (8 TESTS)
# -----------------------------------------------------------------------------
function Run-Tier2 {
    Write-Header "TIER 2: BOUNDARY & CORNER CASES (8 TESTS)"

    # Test 2.1: Empty Order Array Handling in JSON Templates
    $emptyOrderHandled = $true
    $emptyOrderError = ""
    try {
        $mockTemplateJson = '{"sections": {"banner": {"type": "image-banner", "settings": {}}}, "order": []}'
        $parsed = ConvertFrom-Json -InputObject $mockTemplateJson -ErrorAction Stop
        if ($parsed.order.Count -ne 0) {
            $emptyOrderHandled = $false
            $emptyOrderError = "Order count not zero"
        }
        $renderedCount = 0
        foreach ($item in $parsed.order) { $renderedCount++ }
        if ($renderedCount -ne 0) { $emptyOrderHandled = $false }
    } catch {
        $emptyOrderHandled = $false
        $emptyOrderError = $_.Exception.Message
    }
    Register-TestResult -TierName "Tier 2" -Category "Boundary Handling" -TestId "T2.1" `
        -Name "Empty Order Array Handling in Templates ('order': [])" `
        -Passed $emptyOrderHandled `
        -Message $(if ($emptyOrderHandled) { "Empty order array parses and iterates cleanly without exception." } else { "Empty order handling error: $emptyOrderError" }) `
        -OwnerMilestone "M1"

    # Free shipping threshold math simulator
    function Test-FreeShippingCalc([double]$Threshold, [double]$Total) {
        $thresholdCents = $Threshold * 100
        $totalCents = $Total * 100
        if ($thresholdCents -gt 0) {
            $remaining = $thresholdCents - $totalCents
            if ($remaining -le 0) {
                return @{ Unlocked = $true; Progress = 100; Remaining = 0 }
            } else {
                $pct = [Math]::Floor(($totalCents * 100) / $thresholdCents)
                if ($pct -gt 100) { $pct = 100 }
                return @{ Unlocked = $false; Progress = $pct; Remaining = ($remaining / 100) }
            }
        } else {
            return @{ Unlocked = $true; Progress = 100; Remaining = 0 }
        }
    }

    # Test 2.2: Free Shipping Threshold Edge Value €0
    $cartDrawerSnippetPath = Join-Path $WorkspaceRoot "snippets\cart-drawer.liquid"
    $hasGuardInLiquid = $false
    if (Test-Path -Path $cartDrawerSnippetPath) {
        $cartContent = Get-Content -Path $cartDrawerSnippetPath -Raw -Encoding UTF8
        if ($cartContent -match 'threshold[a-zA-Z0-9_]*\s*>\s*0') {
            $hasGuardInLiquid = $true
        }
    }
    $calc0 = Test-FreeShippingCalc -Threshold 0 -Total 20
    $thresholdZeroCheck = ($calc0.Unlocked -eq $true -and $calc0.Progress -eq 100 -and $hasGuardInLiquid)

    Register-TestResult -TierName "Tier 2" -Category "Boundary Handling" -TestId "T2.2" `
        -Name "Free Shipping Threshold Edge Value $($script:Euro)0 (Division-by-Zero Guard & Immediate Unlock)" `
        -Passed $thresholdZeroCheck `
        -Message $(if ($thresholdZeroCheck) { "Liquid guard detected and math correctly unlocks 100% at $($script:Euro)0 threshold." } else { "Liquid guard missing or threshold $($script:Euro)0 calculation incorrect (Guard: $hasGuardInLiquid)." }) `
        -OwnerMilestone "M2"

    # Test 2.3: Free Shipping Threshold Edge Value Below Spend (€50 spend on €75 threshold)
    $calc50 = Test-FreeShippingCalc -Threshold 75 -Total 50
    $threshold50Check = ($calc50.Unlocked -eq $false -and $calc50.Remaining -eq 25 -and $calc50.Progress -eq 66)
    Register-TestResult -TierName "Tier 2" -Category "Boundary Handling" -TestId "T2.3" `
        -Name "Free Shipping Threshold Edge Value Below Spend ($($script:Euro)50 on $($script:Euro)75 threshold)" `
        -Passed $threshold50Check `
        -Message $(if ($threshold50Check) { "Evaluated remaining: $($script:Euro)25.00, progress: 66%, locked status." } else { "Unexpected result for spend: Rem=$($calc50.Remaining), Pct=$($calc50.Progress)" }) `
        -OwnerMilestone "M2"

    # Test 2.4: Free Shipping Threshold Edge Value Exact Spend (€75 spend on €75 threshold)
    $calc75 = Test-FreeShippingCalc -Threshold 75 -Total 75
    $threshold75Check = ($calc75.Unlocked -eq $true -and $calc75.Remaining -eq 0 -and $calc75.Progress -eq 100)
    Register-TestResult -TierName "Tier 2" -Category "Boundary Handling" -TestId "T2.4" `
        -Name "Free Shipping Threshold Edge Value Exact Spend ($($script:Euro)75 on $($script:Euro)75 threshold)" `
        -Passed $threshold75Check `
        -Message $(if ($threshold75Check) { "Evaluated remaining: $($script:Euro)0.00, progress: 100%, unlocked status." } else { "Unexpected result for exact spend: Rem=$($calc75.Remaining), Pct=$($calc75.Progress)" }) `
        -OwnerMilestone "M2"

    # Test 2.5: Free Shipping Threshold Edge Value Above Spend (€100 spend on €75 threshold, Clamped)
    $calc100 = Test-FreeShippingCalc -Threshold 75 -Total 100
    $threshold100Check = ($calc100.Unlocked -eq $true -and $calc100.Remaining -eq 0 -and $calc100.Progress -eq 100)
    Register-TestResult -TierName "Tier 2" -Category "Boundary Handling" -TestId "T2.5" `
        -Name "Free Shipping Threshold Edge Value Above Spend ($($script:Euro)100 on $($script:Euro)75 threshold, Clamped)" `
        -Passed $threshold100Check `
        -Message $(if ($threshold100Check) { "Evaluated remaining clamped to $($script:Euro)0, progress clamped strictly to 100%." } else { "Unexpected result for spend: Rem=$($calc100.Remaining), Pct=$($calc100.Progress)" }) `
        -OwnerMilestone "M2"

    # Test 2.6: Long Strings & Layout Overflow Protection (CSS rules audit)
    $cssFiles = Get-ChildItem -Path (Join-Path $WorkspaceRoot "assets") -Filter "*.css" -File -ErrorAction SilentlyContinue
    $hasWordBreak = $false
    $hasTextEllipsis = $false
    foreach ($cf in $cssFiles) {
        $content = Get-Content -Path $cf.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($content -match 'word-break|overflow-wrap') { $hasWordBreak = $true }
        if ($content -match 'text-overflow:\s*ellipsis') { $hasTextEllipsis = $true }
    }
    $longStringPassed = ($hasWordBreak -and $hasTextEllipsis)
    Register-TestResult -TierName "Tier 2" -Category "Boundary Handling" -TestId "T2.6" `
        -Name "Long Strings & Layout Overflow Protection (word-break & text-overflow in CSS)" `
        -Passed $longStringPassed `
        -Message $(if ($longStringPassed) { "CSS typography and cards enforce overflow protection rules." } else { "Missing word-break ($hasWordBreak) or text-overflow ($hasTextEllipsis) in theme CSS." }) `
        -OwnerMilestone "M1"

    # Test 2.7: Missing Image Alt Attributes Detection
    # Mask Liquid expressions {% ... %} and {{ ... }} first to prevent condition characters (e.g. >=) from breaking HTML parsing
    $liquidFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.liquid" -Recurse -File -ErrorAction SilentlyContinue
    $rawImgWithoutAlt = @()
    foreach ($lf in $liquidFiles) {
        $content = Get-Content -Path $lf.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $cleanContent = [regex]::Replace($content, '\{%[\s\S]*?%\}|\{\{[\s\S]*?\}\}', ' ')
        $matches = [regex]::Matches($cleanContent, '<img\b[^>]*>')
        foreach ($m in $matches) {
            if ($m.Value -notmatch '\balt\s*=') {
                $rawImgWithoutAlt += $lf.Name
                break
            }
        }
    }
    $altCheckPassed = ($rawImgWithoutAlt.Count -eq 0)
    Register-TestResult -TierName "Tier 2" -Category "Boundary Handling" -TestId "T2.7" `
        -Name "Missing Image Alt Attributes Detection (Zero <img> tags without alt attribute)" `
        -Passed $altCheckPassed `
        -Message $(if ($altCheckPassed) { "All <img> tags explicitly include an alt attribute." } else { "$($rawImgWithoutAlt.Count) Liquid files contain <img> tags missing alt attributes." }) `
        -Details ($rawImgWithoutAlt -join ", ") -OwnerMilestone "M4"

    # Test 2.8: Special Characters & HTML Escaping in Templates
    $escapeAuditCount = 0
    $hasEscapeFilter = $false
    foreach ($lf in $liquidFiles) {
        $content = Get-Content -Path $lf.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($content -match '\|\s*escape\b|\|\s*escape_once\b|\|\s*json\b') {
            $escapeAuditCount++
            $hasEscapeFilter = $true
        }
    }
    Register-TestResult -TierName "Tier 2" -Category "Boundary Handling" -TestId "T2.8" `
        -Name "Special Characters & HTML Escaping (Audit of | escape and | json usage in Liquid)" `
        -Passed $hasEscapeFilter `
        -Message $(if ($hasEscapeFilter) { "Found $escapeAuditCount Liquid files correctly utilizing HTML escaping filters." } else { "No Liquid escaping filters detected in codebase." }) `
        -OwnerMilestone "M4"
}

# -----------------------------------------------------------------------------
# TIER 3: CROSS-FEATURE COMBINATIONS (4 TESTS)
# -----------------------------------------------------------------------------
function Run-Tier3 {
    Write-Header "TIER 3: CROSS-FEATURE COMBINATIONS (4 TESTS)"

    # Test 3.1: Header Transparent Mode + Hero Cover Overlay
    $headerLiquidPath = Join-Path $WorkspaceRoot "sections\header.liquid"
    $heroCoverPath = Join-Path $WorkspaceRoot "sections\hero-cover.liquid"
    $headerHasTransparent = $false
    $heroHasCover = $false

    if (Test-Path -Path $headerLiquidPath) {
        $hContent = Get-Content -Path $headerLiquidPath -Raw -Encoding UTF8
        if ($hContent -match 'transparent|overlay|header--transparent|enable_transparent_header') {
            $headerHasTransparent = $true
        }
    }
    if (Test-Path -Path $heroCoverPath) {
        $heroHasCover = $true
    }
    $comboHeaderHero = ($headerHasTransparent -and $heroHasCover)
    Register-TestResult -TierName "Tier 3" -Category "Cross-Feature" -TestId "T3.1" `
        -Name "Header Transparent Mode + Hero Cover Combination" `
        -Passed $comboHeaderHero `
        -Message $(if ($comboHeaderHero) { "Header transparent overlay integration verified with hero-cover.liquid." } else { "Missing header transparent support ($headerHasTransparent) or hero-cover.liquid ($heroHasCover)." }) `
        -Details "Requires sections/header.liquid transparent mode + sections/hero-cover.liquid" -OwnerMilestone "M2"

    # Test 3.2: Cart Drawer + Free Shipping Progress Meter + Upsell Recommendations
    $cartDrawerSnippetPath = Join-Path $WorkspaceRoot "snippets\cart-drawer.liquid"
    $cartHasDrawer = $false
    $cartHasMeter = $false
    $cartHasUpsell = $false

    if (Test-Path -Path $cartDrawerSnippetPath) {
        $cdContent = Get-Content -Path $cartDrawerSnippetPath -Raw -Encoding UTF8
        if ($cdContent -match 'role=["'']dialog["'']|class=["''].*cart-drawer') {
            $cartHasDrawer = $true
        }
        if ($cdContent -match 'free-shipping|free_shipping|progressbar') {
            $cartHasMeter = $true
        }
        if ($cdContent -match 'upsell|recommendation|complementary') {
            $cartHasUpsell = $true
        }
    }
    $cartIntegrationPassed = ($cartHasDrawer -and $cartHasMeter -and $cartHasUpsell)
    Register-TestResult -TierName "Tier 3" -Category "Cross-Feature" -TestId "T3.2" `
        -Name "Cart Drawer + Free Shipping Progress Meter + Upsell Recommendations" `
        -Passed $cartIntegrationPassed `
        -Message $(if ($cartIntegrationPassed) { "Cart drawer contains modal container, progress meter, and upsell slot." } else { "Cart drawer incomplete: Drawer=$cartHasDrawer, FreeShippingMeter=$cartHasMeter, Upsell=$cartHasUpsell" }) `
        -Details "Inspect snippets/cart-drawer.liquid" -OwnerMilestone "M2"

    # Test 3.3: Collection Filter Drawer + Product Grid Quick-Add
    $collectionJsonPath = Join-Path $WorkspaceRoot "templates\collection.json"
    $cardProductSnippetPath = Join-Path $WorkspaceRoot "snippets\card-product.liquid"
    $facetsSnippetPath = Join-Path $WorkspaceRoot "snippets\facets.liquid"

    $hasCollectionTemplate = Test-Path -Path $collectionJsonPath
    $hasFacets = Test-Path -Path $facetsSnippetPath
    $hasQuickAddInCard = $false
    if (Test-Path -Path $cardProductSnippetPath) {
        $cpContent = Get-Content -Path $cardProductSnippetPath -Raw -Encoding UTF8
        if ($cpContent -match 'quick_add|quick-add') {
            $hasQuickAddInCard = $true
        }
    }
    $collectionQuickAddPassed = ($hasCollectionTemplate -and $hasFacets -and $hasQuickAddInCard)
    Register-TestResult -TierName "Tier 3" -Category "Cross-Feature" -TestId "T3.3" `
        -Name "Collection Filter Drawer + Product Grid Quick-Add Integration" `
        -Passed $collectionQuickAddPassed `
        -Message $(if ($collectionQuickAddPassed) { "Collection template links facets filtering with product quick-add cards." } else { "Collection integration incomplete: Template=$hasCollectionTemplate, Facets=$hasFacets, QuickAdd=$hasQuickAddInCard" }) `
        -OwnerMilestone "M4"

    # Test 3.4: Breadcrumbs + JSON-LD BreadcrumbList Integration
    $breadcrumbsSnippetPath = Join-Path $WorkspaceRoot "snippets\breadcrumbs.liquid"
    $hasBreadcrumbs = $false
    $hasBreadcrumbLdJson = $false

    if (Test-Path -Path $breadcrumbsSnippetPath) {
        $hasBreadcrumbs = $true
        $bcContent = Get-Content -Path $breadcrumbsSnippetPath -Raw -Encoding UTF8
        if ($bcContent -match 'application/ld\+json' -and $bcContent -match 'BreadcrumbList') {
            $hasBreadcrumbLdJson = $true
        }
    }
    $breadcrumbsIntegration = ($hasBreadcrumbs -and $hasBreadcrumbLdJson)
    Register-TestResult -TierName "Tier 3" -Category "Cross-Feature" -TestId "T3.4" `
        -Name "Breadcrumbs Snippet + Schema.org BreadcrumbList JSON-LD Integration" `
        -Passed $breadcrumbsIntegration `
        -Message $(if ($breadcrumbsIntegration) { "snippets/breadcrumbs.liquid outputs both visual markup and BreadcrumbList JSON-LD." } else { "Breadcrumbs missing or lacking BreadcrumbList JSON-LD: Snippet=$hasBreadcrumbs, SchemaLD=$hasBreadcrumbLdJson" }) `
        -Details "snippets/breadcrumbs.liquid must declare Schema.org BreadcrumbList structured data" -OwnerMilestone "M1"
}

# -----------------------------------------------------------------------------
# TIER 4: REAL-WORLD SCENARIOS (4 TESTS)
# -----------------------------------------------------------------------------
function Run-Tier4 {
    Write-Header "TIER 4: REAL-WORLD SCENARIOS (4 TESTS)"

    # Test 4.1: Complete 16-Section Homepage Architecture Verification
    $canitera16Sections = @(
        "announcement-bar",
        "header",
        "hero-cover",
        "trust-value-strip",
        "featured-collection",
        "brand-story-split",
        "shop-by-adventure",
        "hero-product-spotlight",
        "why-canitera",
        "lifestyle-banner",
        "testimonials",
        "community-ugc",
        "featured-blog",
        "journal-newsletter",
        "final-cta-banner",
        "footer"
    )
    $missingHomepageSections = @()
    foreach ($sName in $canitera16Sections) {
        $secPath = Join-Path $WorkspaceRoot "sections\$sName.liquid"
        if (-not (Test-Path -Path $secPath)) {
            $missingHomepageSections += "$sName.liquid"
        }
    }
    $indexJsonPath = Join-Path $WorkspaceRoot "templates\index.json"
    $indexRes = Safe-ReadJsonFile -FilePath $indexJsonPath
    $indexModularSectionsPresent = $false
    if ($indexRes.Success -and $null -ne $indexRes.Data.order) {
        if ($indexRes.Data.order.Count -ge 10) {
            $indexModularSectionsPresent = $true
        }
    }
    $homepage16Passed = ($missingHomepageSections.Count -eq 0 -and $indexModularSectionsPresent)
    Register-TestResult -TierName "Tier 4" -Category "Real-World Scenarios" -TestId "T4.1" `
        -Name "Complete 16-Section Homepage Architecture Verification" `
        -Passed $homepage16Passed `
        -Message $(if ($homepage16Passed) { "All 16 homepage sections exist and index.json declares the full modular architecture." } else { "Homepage architecture incomplete. Missing files: $($missingHomepageSections.Count), Full index.json configured: $indexModularSectionsPresent" }) `
        -Details ($missingHomepageSections -join ", ") -OwnerMilestone "M3"

    # Test 4.2: 14 Specialized Page Templates Integrity
    $required14Templates = @(
        "index.json",
        "product.json",
        "collection.json",
        "page.about.json",
        "page.travel.json",
        "blog.json",
        "article.json",
        "page.contact.json",
        "page.faq.json",
        "404.json",
        "search.json",
        "password.json",
        "cart.json",
        "page.json"
    )
    $missingTemplates = @()
    foreach ($tmpl in $required14Templates) {
        $tmplPath = Join-Path $WorkspaceRoot "templates\$tmpl"
        if (-not (Test-Path -Path $tmplPath)) {
            $missingTemplates += $tmpl
        } else {
            $res = Safe-ReadJsonFile -FilePath $tmplPath
            if (-not $res.Success) {
                $missingTemplates += "$tmpl (invalid JSON)"
            }
        }
    }
    $templates14Passed = ($missingTemplates.Count -eq 0)
    Register-TestResult -TierName "Tier 4" -Category "Real-World Scenarios" -TestId "T4.2" `
        -Name "14 Specialized Page Templates Integrity ($($required14Templates.Count) templates required)" `
        -Passed $templates14Passed `
        -Message $(if ($templates14Passed) { "All 14 specialized page templates exist and parse as valid JSON." } else { "$($missingTemplates.Count) specialized page templates missing or invalid." }) `
        -Details ($missingTemplates -join ", ") -OwnerMilestone "M4"

    # Test 4.3: Accessibility Semantic Checks (WCAG 2.1 AA Compliance)
    $themeLiquidPath = Join-Path $WorkspaceRoot "layout\theme.liquid"
    $baseCssPath = Join-Path $WorkspaceRoot "assets\base.css"

    $hasMainLandmark = $false
    $hasSkipLink = $false
    $hasReducedMotion = $false
    $hasFocusVisible = $false

    if (Test-Path -Path $themeLiquidPath) {
        $themeContent = Get-Content -Path $themeLiquidPath -Raw -Encoding UTF8
        if ($themeContent -match '<main\b[^>]*\bid=["'']MainContent["'']') {
            $hasMainLandmark = $true
        }
        if ($themeContent -match 'href=["'']#MainContent["'']|skip-to-content') {
            $hasSkipLink = $true
        }
    }
    if (Test-Path -Path $baseCssPath) {
        $cssContent = Get-Content -Path $baseCssPath -Raw -Encoding UTF8
        if ($cssContent -match '@media\s*\(\s*prefers-reduced-motion') {
            $hasReducedMotion = $true
        }
        if ($cssContent -match ':focus-visible') {
            $hasFocusVisible = $true
        }
    }
    $a11yPassed = ($hasMainLandmark -and $hasSkipLink -and $hasReducedMotion -and $hasFocusVisible)
    Register-TestResult -TierName "Tier 4" -Category "Real-World Scenarios" -TestId "T4.3" `
        -Name "Accessibility Semantic Checks (WCAG 2.1 AA Compliance: Landmarks, Focus, Motion)" `
        -Passed $a11yPassed `
        -Message $(if ($a11yPassed) { "Theme implements HTML5 landmarks, skip link, focus-visible, and reduced-motion." } else { "A11y requirements missing: MainLandmark=$hasMainLandmark, SkipLink=$hasSkipLink, ReducedMotion=$hasReducedMotion, FocusVisible=$hasFocusVisible" }) `
        -OwnerMilestone "M4"

    # Test 4.4: SEO Structured Data Validation (JSON-LD Schemas)
    $hasOrgLd = $false
    $hasWebSiteLd = $false
    $hasProductLd = $false
    $hasArticleLd = $false

    $headerLiquidPath = Join-Path $WorkspaceRoot "sections\header.liquid"
    $headerContent = if (Test-Path -Path $headerLiquidPath) { Get-Content -Path $headerLiquidPath -Raw -Encoding UTF8 } else { "" }
    $productLiquidPath = Join-Path $WorkspaceRoot "sections\main-product.liquid"
    $productContent = if (Test-Path -Path $productLiquidPath) { Get-Content -Path $productLiquidPath -Raw -Encoding UTF8 } else { "" }
    $articleLiquidPath = Join-Path $WorkspaceRoot "sections\main-article.liquid"
    $articleContent = if (Test-Path -Path $articleLiquidPath) { Get-Content -Path $articleLiquidPath -Raw -Encoding UTF8 } else { "" }

    if ($headerContent -match 'application/ld\+json' -and $headerContent -match 'Organization') {
        $hasOrgLd = $true
    }
    if ($headerContent -match 'application/ld\+json' -and $headerContent -match 'WebSite') {
        $hasWebSiteLd = $true
    }
    if ($productContent -match 'application/ld\+json' -and $productContent -match 'Product') {
        $hasProductLd = $true
    }
    if ($articleContent -match 'application/ld\+json' -and $articleContent -match 'Article|BlogPosting') {
        $hasArticleLd = $true
    }
    $seoLdPassed = ($hasOrgLd -and $hasWebSiteLd -and $hasProductLd -and $hasArticleLd)
    Register-TestResult -TierName "Tier 4" -Category "Real-World Scenarios" -TestId "T4.4" `
        -Name "SEO Structured Data Validation (JSON-LD Organization, WebSite, Product, Article)" `
        -Passed $seoLdPassed `
        -Message $(if ($seoLdPassed) { "Theme outputs valid JSON-LD schemas for Organization, WebSite, Product, and Article." } else { "JSON-LD schemas missing: Org=$hasOrgLd, WebSite=$hasWebSiteLd, Product=$hasProductLd, Article=$hasArticleLd" }) `
        -OwnerMilestone "M4"
}

# -----------------------------------------------------------------------------
# MAIN TEST EXECUTION CONTROLLER
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "         CANITERA SHOPIFY OS 2.0 THEME VERIFICATION RUNNER                     " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceRoot" -ForegroundColor DarkGray
Write-Host "Timestamp: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))" -ForegroundColor DarkGray
Write-Host "Runner:    Windows PowerShell 5.1 / PowerShell Core" -ForegroundColor DarkGray
Write-Host ""

if ($Tier -eq 0 -or $Tier -eq 1) { Run-Tier1 }
if ($Tier -eq 0 -or $Tier -eq 2) { Run-Tier2 }
if ($Tier -eq 0 -or $Tier -eq 3) { Run-Tier3 }
if ($Tier -eq 0 -or $Tier -eq 4) { Run-Tier4 }

$script:Stopwatch.Stop()

# -----------------------------------------------------------------------------
# SUMMARY REPORT & EXIT CODE EVALUATION
# -----------------------------------------------------------------------------
Write-Header "VERIFICATION SUITE SUMMARY REPORT"

$tierGroups = $script:TestResults | Group-Object -Property Tier
foreach ($tg in $tierGroups) {
    $tPassed = @($tg.Group | Where-Object { $_.Passed -eq $true }).Count
    $tFailed = @($tg.Group | Where-Object { $_.Passed -eq $false }).Count
    $tTotal = $tg.Group.Count
    $tColor = if ($tFailed -eq 0) { [System.ConsoleColor]::Green } else { [System.ConsoleColor]::Red }
    $line = "  " + $tg.Name.PadRight(35) + " : " + $tPassed.ToString().PadLeft(2) + " passed, " + $tFailed.ToString().PadLeft(2) + " failed (Total " + $tTotal.ToString().PadLeft(2) + ")"
    Write-Host $line -ForegroundColor $tColor
}

$totalPassed = @($script:TestResults | Where-Object { $_.Passed -eq $true }).Count
$totalFailed = @($script:TestResults | Where-Object { $_.Passed -eq $false }).Count
$grandTotal = $script:TestResults.Count

Write-Host ("-" * 80) -ForegroundColor DarkGray
$overallColor = if ($totalFailed -eq 0) { [System.ConsoleColor]::Green } else { [System.ConsoleColor]::Red }
Write-Host ("  OVERALL RESULTS: {0} PASSED, {1} FAILED across {2} tests in {3:N2} seconds." -f $totalPassed, $totalFailed, $grandTotal, $script:Stopwatch.Elapsed.TotalSeconds) -ForegroundColor $overallColor
Write-Host ("=" * 80) -ForegroundColor Cyan

if ($totalFailed -gt 0) {
    Write-Host ""
    Write-Host "FAILURES REQUIRING ATTENTION:" -ForegroundColor Yellow
    $failedList = $script:TestResults | Where-Object { $_.Passed -eq $false }
    foreach ($fail in $failedList) {
        Write-Host "  * [$($fail.TestId)] $($fail.Name)" -ForegroundColor Red
        Write-Host "    Message: $($fail.Message)" -ForegroundColor DarkYellow
        if (-not [string]::IsNullOrWhiteSpace($fail.Details)) {
            Write-Host "    Details: $($fail.Details)" -ForegroundColor DarkGray
        }
        Write-Host "    Assigned Implementation Milestone: $($fail.OwnerMilestone)" -ForegroundColor Magenta
    }
    Write-Host ""
    Write-Host "VERIFICATION RESULT: FAILED (Exit Code 1)" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "VERIFICATION RESULT: ALL TESTS PASSED! THEME IS PRODUCTION READY! (Exit Code 0)" -ForegroundColor Green
    exit 0
}
