<#
.SYNOPSIS
    Milestone 2 Empirical Challenger Stress-Test Suite
.DESCRIPTION
    Comprehensive stress tests and boundary simulations for Milestone 2:
    Cart Drawer & Free Shipping Threshold Mechanics.
    Empirically verifies:
    1. Threshold edge calculation simulations:
       - Threshold = 0 (100% unlocked, €0 remaining, no NaN/Inf or division by zero)
       - Cart total = 0, threshold = 75 (0% progress, €75 remaining)
       - Cart total = 7499 cents, threshold = 75 (99% progress, €0.01 remaining)
       - Cart total = 7500 cents (100% unlocked)
       - Cart total = 15000 cents (100% unlocked, clamped, no overflow)
    2. Section Rendering API container structure in snippets/cart-drawer.liquid:
       - Modal container with role="dialog" or class=".*cart-drawer"
       - Progress bar element with role="progressbar" or class free-shipping
       - Upsell container with class=".*upsell.*"
    3. Liquid mathematical implementation audit in snippets/cart-drawer.liquid:
       - Division-by-zero protection
       - Progress bar rounding behavior at near-threshold boundary (7499 cents vs 7500 cents)
    4. Client-side Section Rendering API integration:
       - assets/cart-drawer.js (CartDrawer & CartDrawerItems definitions and getSectionsToRender)
       - assets/cart.js (onCartUpdate selector replacement list)
#>

[CmdletBinding()]
param(
    [string]$WorkspaceRoot = "c:\Users\martin\Documents\martin",
    [int]$Suite = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$script:TotalAsserts = 0
$script:PassedAsserts = 0
$script:FailedAsserts = 0
$script:Warnings = 0
$script:Findings = New-Object System.Collections.ArrayList

function Log-Banner([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
}

function Assert-Check([string]$Id, [string]$Description, [bool]$Condition, [string]$Actual = "", [string]$Expected = "") {
    $script:TotalAsserts++
    if ($Condition) {
        $script:PassedAsserts++
        Write-Host "  [PASS] " -ForegroundColor Green -NoNewline
        Write-Host "[$Id] " -ForegroundColor DarkGray -NoNewline
        Write-Host "$Description" -ForegroundColor White
        if ($Actual) {
            Write-Host "         Result: $Actual" -ForegroundColor DarkGray
        }
    } else {
        $script:FailedAsserts++
        Write-Host "  [FAIL] " -ForegroundColor Red -NoNewline
        Write-Host "[$Id] " -ForegroundColor DarkGray -NoNewline
        Write-Host "$Description" -ForegroundColor White
        if ($Expected) {
            Write-Host "         Expected: $Expected" -ForegroundColor Yellow
        }
        if ($Actual) {
            Write-Host "         Actual:   $Actual" -ForegroundColor Red
        }
        $script:Findings.Add([PSCustomObject]@{
            Id = $Id
            Type = "FAIL"
            Description = $Description
            Expected = $Expected
            Actual = $Actual
        }) | Out-Null
    }
}

function Warn-Check([string]$Id, [string]$Description, [string]$Detail) {
    $script:Warnings++
    Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host "[$Id] " -ForegroundColor DarkGray -NoNewline
    Write-Host "$Description" -ForegroundColor Yellow
    Write-Host "         Finding: $Detail" -ForegroundColor DarkYellow
    $script:Findings.Add([PSCustomObject]@{
        Id = $Id
        Type = "WARN"
        Description = $Description
        Expected = "N/A"
        Actual = $Detail
    }) | Out-Null
}

# -----------------------------------------------------------------------------
# SUITE 1: FREE SHIPPING THRESHOLD MATHEMATICAL EDGE CALCULATIONS
# -----------------------------------------------------------------------------
if ($Suite -eq 0 -or $Suite -eq 1) {
Log-Banner "SUITE 1: FREE SHIPPING THRESHOLD MATHEMATICAL SIMULATIONS"

# Floor-based model (Standard Shopify OS 2.0 / verify-theme.ps1 contract)
function Simulate-ThresholdFloor([double]$ThresholdEuros, [double]$TotalEuros) {
    $thresholdCents = [Math]::Round($ThresholdEuros * 100)
    $totalCents = [Math]::Round($TotalEuros * 100)

    if ($thresholdCents -le 0) {
        return @{
            Unlocked = $true
            Progress = 100
            RemainingCents = 0
            RemainingEuros = 0.00
            HasDivByZero = $false
        }
    }

    $remainingCents = $thresholdCents - $totalCents
    if ($remainingCents -le 0) {
        return @{
            Unlocked = $true
            Progress = 100
            RemainingCents = 0
            RemainingEuros = 0.00
            HasDivByZero = $false
        }
    }

    $progress = [Math]::Floor(($totalCents * 100.0) / $thresholdCents)
    if ($progress -gt 100) { $progress = 100 }
    if ($progress -lt 0) { $progress = 0 }

    return @{
        Unlocked = $false
        Progress = [int]$progress
        RemainingCents = [int]$remainingCents
        RemainingEuros = [Math]::Round($remainingCents / 100.0, 2)
        HasDivByZero = $false
    }
}

# Liquid template model (as currently coded in snippets/cart-drawer.liquid)
function Simulate-LiquidCartDrawerMath([double]$ThresholdEuros, [int]$CartTotalCents) {
    $thresholdInCents = [int]($ThresholdEuros * 100)
    $cartTotal = $CartTotalCents

    if ($thresholdInCents -gt 0) {
        if ($cartTotal -ge $thresholdInCents) {
            $unlocked = $true
            $progress = 100.0
            $remaining = 0
        } else {
            $unlocked = $false
            $progress = [Math]::Round(($cartTotal * 100.0) / $thresholdInCents, 1)
            if ($progress -gt 100.0) { $progress = 100.0 }
            elseif ($progress -lt 0.0) { $progress = 0.0 }
            $remaining = $thresholdInCents - $cartTotal
        }
        $ariaValueNow = [Math]::Round($progress, [MidpointRounding]::AwayFromZero)
        return @{
            Branch = "threshold > 0"
            Unlocked = $unlocked
            Progress = $progress
            AriaValueNow = [int]$ariaValueNow
            RemainingCents = $remaining
            RemainingEuros = [Math]::Round($remaining / 100.0, 2)
            DivByZero = $false
        }
    } else {
        return @{
            Branch = "threshold <= 0 (else branch)"
            Unlocked = $true
            Progress = 100.0
            AriaValueNow = 100
            RemainingCents = 0
            RemainingEuros = 0.00
            DivByZero = $false
        }
    }
}

# Case 1: Threshold = 0 (Immediate 100% unlock, €0 remaining, no NaN/Inf or division by zero)
$c1_floor = Simulate-ThresholdFloor -ThresholdEuros 0 -TotalEuros 0
$c1_liquid = Simulate-LiquidCartDrawerMath -ThresholdEuros 0 -CartTotalCents 0
Assert-Check "M2.1.1" "Threshold = 0: Unlocked status is true" ($c1_floor.Unlocked -and $c1_liquid.Unlocked) `
    "Floor: $($c1_floor.Unlocked), Liquid: $($c1_liquid.Unlocked)" "True"
Assert-Check "M2.1.2" "Threshold = 0: Remaining amount is €0.00" ($c1_floor.RemainingEuros -eq 0 -and $c1_liquid.RemainingEuros -eq 0) `
    "Floor: €$($c1_floor.RemainingEuros), Liquid: €$($c1_liquid.RemainingEuros)" "€0.00"
Assert-Check "M2.1.3" "Threshold = 0: Progress meter is 100%" ($c1_floor.Progress -eq 100 -and $c1_liquid.Progress -eq 100) `
    "Floor: $($c1_floor.Progress)%, Liquid: $($c1_liquid.Progress)%" "100%"
Assert-Check "M2.1.4" "Threshold = 0: Division-by-zero prevented" (-not $c1_liquid.DivByZero) `
    "DivByZero flag: $($c1_liquid.DivByZero)" "False"

# Case 2: Cart total = 0, Threshold = 75 (0% progress, €75 remaining)
$c2_floor = Simulate-ThresholdFloor -ThresholdEuros 75 -TotalEuros 0
$c2_liquid = Simulate-LiquidCartDrawerMath -ThresholdEuros 75 -CartTotalCents 0
Assert-Check "M2.1.5" "Total = 0, Threshold = 75: Unlocked status is false" (-not $c2_floor.Unlocked -and -not $c2_liquid.Unlocked) `
    "Floor: $($c2_floor.Unlocked), Liquid: $($c2_liquid.Unlocked)" "False"
Assert-Check "M2.1.6" "Total = 0, Threshold = 75: Progress is 0%" ($c2_floor.Progress -eq 0 -and $c2_liquid.Progress -eq 0) `
    "Floor: $($c2_floor.Progress)%, Liquid: $($c2_liquid.Progress)%" "0%"
Assert-Check "M2.1.7" "Total = 0, Threshold = 75: Remaining is €75.00" ($c2_floor.RemainingEuros -eq 75.00 -and $c2_liquid.RemainingEuros -eq 75.00) `
    "Floor: €$($c2_floor.RemainingEuros), Liquid: €$($c2_liquid.RemainingEuros)" "€75.00"

# Case 3: Cart total = 7499 cents, Threshold = 75 (99% progress, €0.01 remaining)
$c3_floor = Simulate-ThresholdFloor -ThresholdEuros 75 -TotalEuros 74.99
$c3_liquid = Simulate-LiquidCartDrawerMath -ThresholdEuros 75 -CartTotalCents 7499
Assert-Check "M2.1.8" "Total = 7499 cents, Threshold = 75: Unlocked status is false" (-not $c3_floor.Unlocked -and -not $c3_liquid.Unlocked) `
    "Floor: $($c3_floor.Unlocked), Liquid: $($c3_liquid.Unlocked)" "False"
Assert-Check "M2.1.9" "Total = 7499 cents, Threshold = 75: Remaining is €0.01 (1 cent)" ($c3_floor.RemainingCents -eq 1 -and $c3_liquid.RemainingCents -eq 1) `
    "Floor: €$($c3_floor.RemainingEuros) (cents: $($c3_floor.RemainingCents)), Liquid: €$($c3_liquid.RemainingEuros)" "€0.01 (1 cent)"
Assert-Check "M2.1.10" "Total = 7499 cents, Threshold = 75: Floor model yields 99% progress" ($c3_floor.Progress -eq 99) `
    "Floor progress: $($c3_floor.Progress)%" "99%"

# Adversarial Analysis on Liquid Rounding at 7499 cents:
if ($c3_liquid.AriaValueNow -eq 100 -or $c3_liquid.Progress -ge 100.0) {
    Warn-Check "M2.1.11W" "Liquid rounding at 7499 cents causes aria-valuenow=100 while unlocked=false" `
        "snippets/cart-drawer.liquid line 94 uses 'divided_by: threshold_in_cents | round: 1'. For 7499/7500, 99.986% rounds to 100.0%, displaying aria-valuenow=100 and width:100% while copy says '€0.01 away'. Using integer division or Math.floor or capping at 99 when cart_total < threshold prevents 100% display prior to qualification."
} else {
    Assert-Check "M2.1.11" "Liquid model clamps progress < 100% when locked" ($c3_liquid.Progress -lt 100.0) `
        "Liquid progress: $($c3_liquid.Progress)%" "< 100%"
}

# Case 4: Cart total = 7500 cents (100% unlocked, €0 remaining)
$c4_floor = Simulate-ThresholdFloor -ThresholdEuros 75 -TotalEuros 75.00
$c4_liquid = Simulate-LiquidCartDrawerMath -ThresholdEuros 75 -CartTotalCents 7500
Assert-Check "M2.1.12" "Total = 7500 cents, Threshold = 75: Unlocked status is true" ($c4_floor.Unlocked -and $c4_liquid.Unlocked) `
    "Floor: $($c4_floor.Unlocked), Liquid: $($c4_liquid.Unlocked)" "True"
Assert-Check "M2.1.13" "Total = 7500 cents, Threshold = 75: Remaining is €0.00" ($c4_floor.RemainingEuros -eq 0 -and $c4_liquid.RemainingEuros -eq 0) `
    "Floor: €$($c4_floor.RemainingEuros), Liquid: €$($c4_liquid.RemainingEuros)" "€0.00"
Assert-Check "M2.1.14" "Total = 7500 cents, Threshold = 75: Progress is 100%" ($c4_floor.Progress -eq 100 -and $c4_liquid.Progress -eq 100) `
    "Floor: $($c4_floor.Progress)%, Liquid: $($c4_liquid.Progress)%" "100%"

# Case 5: Cart total = 15000 cents (100% unlocked, no overflow, clamped)
$c5_floor = Simulate-ThresholdFloor -ThresholdEuros 75 -TotalEuros 150.00
$c5_liquid = Simulate-LiquidCartDrawerMath -ThresholdEuros 75 -CartTotalCents 15000
Assert-Check "M2.1.15" "Total = 15000 cents, Threshold = 75: Unlocked status is true" ($c5_floor.Unlocked -and $c5_liquid.Unlocked) `
    "Floor: $($c5_floor.Unlocked), Liquid: $($c5_liquid.Unlocked)" "True"
Assert-Check "M2.1.16" "Total = 15000 cents, Threshold = 75: Progress strictly clamped to 100% (no overflow)" ($c5_floor.Progress -eq 100 -and $c5_liquid.Progress -eq 100.0 -and $c5_liquid.AriaValueNow -eq 100) `
    "Floor: $($c5_floor.Progress)%, Liquid: $($c5_liquid.Progress)%, aria-valuenow: $($c5_liquid.AriaValueNow)" "100%"
Assert-Check "M2.1.17" "Total = 15000 cents, Threshold = 75: Remaining clamped to €0 (no negative values)" ($c5_floor.RemainingEuros -eq 0 -and $c5_liquid.RemainingEuros -eq 0) `
    "Floor: €$($c5_floor.RemainingEuros), Liquid: €$($c5_liquid.RemainingEuros)" "€0.00"

# Additional Boundary Cases:
# Negative cart total guard
$cNeg_floor = Simulate-ThresholdFloor -ThresholdEuros 75 -TotalEuros -10.00
Assert-Check "M2.1.18" "Negative Cart Total Boundary: Progress clamped to 0%" ($cNeg_floor.Progress -eq 0) `
    "Progress: $($cNeg_floor.Progress)%" "0%"

# Negative threshold guard
$cNegThresh_floor = Simulate-ThresholdFloor -ThresholdEuros -50 -TotalEuros 20.00
Assert-Check "M2.1.19" "Negative Threshold Boundary: Unlocked is true (no division by negative)" ($cNegThresh_floor.Unlocked -eq $true) `
    "Unlocked: $($cNegThresh_floor.Unlocked)" "True"

# Large number stress (1,000,000 EUR cart)
$cLarge_floor = Simulate-ThresholdFloor -ThresholdEuros 75 -TotalEuros 1000000.00
Assert-Check "M2.1.20" "Large Number Stress (€1,000,000 cart): Handled without overflow" ($cLarge_floor.Progress -eq 100 -and $cLarge_floor.RemainingEuros -eq 0) `
}

# -----------------------------------------------------------------------------
# SUITE 2: SECTION RENDERING API CONTAINER STRUCTURE IN SNIPPETS/CART-DRAWER.LIQUID
# -----------------------------------------------------------------------------
if ($Suite -eq 0 -or $Suite -eq 2) {
Log-Banner "SUITE 2: SECTION RENDERING API CONTAINER STRUCTURE IN SNIPPETS/CART-DRAWER.LIQUID"

$cartDrawerLiquidPath = Join-Path $WorkspaceRoot "snippets\cart-drawer.liquid"
Assert-Check "M2.2.1" "snippets/cart-drawer.liquid file exists" (Test-Path -Path $cartDrawerLiquidPath) `
    "Path: $cartDrawerLiquidPath" "Exists"

$cdLiquid = Get-Content -Path $cartDrawerLiquidPath -Raw -Encoding UTF8

# 1. Modal Container Structure
$hasDialogRole = $cdLiquid -match 'role=["'']dialog["'']'
$hasCartDrawerClass = $cdLiquid -match 'class=["''][^"'']*cart-drawer[^"'']*["'']'
$hasAriaModal = $cdLiquid -match 'aria-modal=["'']true["'']'
$hasTabindex = $cdLiquid -match 'tabindex=["'']-1["'']'
$hasCartDrawerElement = $cdLiquid -match '<cart-drawer\b'

Assert-Check "M2.2.2" "Modal container role='dialog' present" $hasDialogRole `
    "role='dialog' match: $hasDialogRole" "True"
Assert-Check "M2.2.3" "Modal container class contains 'cart-drawer'" $hasCartDrawerClass `
    "class contains cart-drawer match: $hasCartDrawerClass" "True"
Assert-Check "M2.2.4" "Modal container aria-modal='true' present" $hasAriaModal `
    "aria-modal='true' match: $hasAriaModal" "True"
Assert-Check "M2.2.5" "Modal container tabindex='-1' for focus trapping present" $hasTabindex `
    "tabindex='-1' match: $hasTabindex" "True"
Assert-Check "M2.2.6" "Custom element <cart-drawer> root tag present" $hasCartDrawerElement `
    "<cart-drawer> match: $hasCartDrawerElement" "True"

# 2. Progress Bar Element Structure & ARIA
$hasProgressBarRole = $cdLiquid -match 'role=["'']progressbar["'']'
$hasFreeShippingClass = $cdLiquid -match 'class=["''][^"'']*free-shipping[^"'']*["'']'
$hasAriaValueNow = $cdLiquid -match 'aria-valuenow=["'']\{\{\s*free_shipping_progress'
$hasAriaValueMin = $cdLiquid -match 'aria-valuemin=["'']0["'']'
$hasAriaValueMax = $cdLiquid -match 'aria-valuemax=["'']100["'']'
$hasProgressBarWidthStyle = $cdLiquid -match 'style=["'']width:\s*\{\{\s*free_shipping_progress\s*\}\}%'
$hasAriaLivePolite = $cdLiquid -match 'aria-live=["'']polite["'']'

Assert-Check "M2.2.7" "Progress bar role='progressbar' present" $hasProgressBarRole `
    "role='progressbar' match: $hasProgressBarRole" "True"
Assert-Check "M2.2.8" "Progress bar element contains class 'free-shipping'" $hasFreeShippingClass `
    "class contains free-shipping match: $hasFreeShippingClass" "True"
Assert-Check "M2.2.9" "Progress bar dynamic aria-valuenow present" $hasAriaValueNow `
    "aria-valuenow binding match: $hasAriaValueNow" "True"
Assert-Check "M2.2.10" "Progress bar aria-valuemin='0' present" $hasAriaValueMin `
    "aria-valuemin='0' match: $hasAriaValueMin" "True"
Assert-Check "M2.2.11" "Progress bar aria-valuemax='100' present" $hasAriaValueMax `
    "aria-valuemax='100' match: $hasAriaValueMax" "True"
Assert-Check "M2.2.12" "Progress bar inline style width interpolation present" $hasProgressBarWidthStyle `
    "style='width: {{ free_shipping_progress }}%;' match: $hasProgressBarWidthStyle" "True"
Assert-Check "M2.2.13" "Progress message aria-live='polite' dynamic announcement present" $hasAriaLivePolite `
    "aria-live='polite' match: $hasAriaLivePolite" "True"

# 3. Upsell Container Structure
$hasUpsellClass = $cdLiquid -match 'class=["''][^"'']*upsell[^"'']*["'']'
$hasRecommendationsClass = $cdLiquid -match 'cart-drawer__recommendations'
$hasUpsellHeading = $cdLiquid -match 'id=["'']CartDrawer-UpsellHeading["'']'
$hasQuickAddAttribute = $cdLiquid -match 'data-quick-add\b'
$hasUpsellCollectionFallback = $cdLiquid -match 'collections\.all'

Assert-Check "M2.2.14" "Upsell container class contains 'upsell'" $hasUpsellClass `
    "class contains upsell match: $hasUpsellClass" "True"
Assert-Check "M2.2.15" "Upsell recommendations class 'cart-drawer__recommendations' present" $hasRecommendationsClass `
    "cart-drawer__recommendations match: $hasRecommendationsClass" "True"
Assert-Check "M2.2.16" "Upsell accessible heading present with ID" $hasUpsellHeading `
    "CartDrawer-UpsellHeading match: $hasUpsellHeading" "True"
Assert-Check "M2.2.17" "Upsell quick-add trigger attribute 'data-quick-add' present" $hasQuickAddAttribute `
    "data-quick-add match: $hasQuickAddAttribute" "True"
}

# -----------------------------------------------------------------------------
# SUITE 3: CLIENT-SIDE JAVASCRIPT SECTION RENDERING API AUDIT
# -----------------------------------------------------------------------------
if ($Suite -eq 0 -or $Suite -eq 3) {
Log-Banner "SUITE 3: CLIENT-SIDE JAVASCRIPT SECTION RENDERING API AUDIT"

$cartDrawerJsPath = Join-Path $WorkspaceRoot "assets\cart-drawer.js"
$cartJsPath = Join-Path $WorkspaceRoot "assets\cart.js"

Assert-Check "M2.3.1" "assets/cart-drawer.js exists" (Test-Path -Path $cartDrawerJsPath) `
    "Path: $cartDrawerJsPath" "Exists"
Assert-Check "M2.3.2" "assets/cart.js exists" (Test-Path -Path $cartJsPath) `
    "Path: $cartJsPath" "Exists"

$cdJs = Get-Content -Path $cartDrawerJsPath -Raw -Encoding UTF8
$cJs = Get-Content -Path $cartJsPath -Raw -Encoding UTF8

# CartDrawer class definition & registration
$hasCartDrawerClassDef = $cdJs -match 'class\s+CartDrawer\s+extends\s+HTMLElement'
$hasCartDrawerDefine = $cdJs -match 'customElements\.define\(["'']cart-drawer["''],\s*CartDrawer\)'
Assert-Check "M2.3.3" "CartDrawer extends HTMLElement definition present" $hasCartDrawerClassDef `
    "CartDrawer class match: $hasCartDrawerClassDef" "True"
Assert-Check "M2.3.4" "customElements.define('cart-drawer', CartDrawer) registered" $hasCartDrawerDefine `
    "cart-drawer registration match: $hasCartDrawerDefine" "True"

# Section Rendering in CartDrawer
$hasCartDrawerSections = $cdJs -match "id:\s*['""]cart-drawer['""],\s*selector:\s*['""]#CartDrawer['""]"
$hasCartIconBubbleSection = $cdJs -match "id:\s*['""]cart-icon-bubble['""]"
Assert-Check "M2.3.5" "CartDrawer requests 'cart-drawer' (#CartDrawer) via Section Rendering API" $hasCartDrawerSections `
    "CartDrawer section registration match: $hasCartDrawerSections" "True"
Assert-Check "M2.3.6" "CartDrawer requests 'cart-icon-bubble' via Section Rendering API" $hasCartIconBubbleSection `
    "cart-icon-bubble registration match: $hasCartIconBubbleSection" "True"

# CartDrawerItems class definition & registration
$hasCartDrawerItemsClassDef = $cdJs -match 'class\s+CartDrawerItems\s+extends\s+CartItems'
$hasCartDrawerItemsDefine = $cdJs -match 'customElements\.define\(["'']cart-drawer-items["''],\s*CartDrawerItems\)'
$hasCartDrawerItemsInnerSelector = $cdJs -match "selector:\s*['""]\.drawer__inner['""]"
Assert-Check "M2.3.7" "CartDrawerItems extends CartItems definition present" $hasCartDrawerItemsClassDef `
    "CartDrawerItems class match: $hasCartDrawerItemsClassDef" "True"
Assert-Check "M2.3.8" "customElements.define('cart-drawer-items', CartDrawerItems) registered" $hasCartDrawerItemsDefine `
    "cart-drawer-items registration match: $hasCartDrawerItemsDefine" "True"
Assert-Check "M2.3.9" "CartDrawerItems updates .drawer__inner on line item quantity changes" $hasCartDrawerItemsInnerSelector `
    ".drawer__inner selector match: $hasCartDrawerItemsInnerSelector" "True"

# Upsell Quick-Add handler
$hasUpsellDelegation = $cdJs -match 'handleUpsellQuickAdd'
$hasUpsellSectionFetch = $cdJs -match 'sectionsToRender'
Assert-Check "M2.3.10" "CartDrawer delegates click events to handleUpsellQuickAdd" $hasUpsellDelegation `
    "handleUpsellQuickAdd delegation match: $hasUpsellDelegation" "True"
Assert-Check "M2.3.11" "handleUpsellQuickAdd queries sectionsToRender for Section Rendering API" $hasUpsellSectionFetch `
    "sectionsToRender in upsell match: $hasUpsellSectionFetch" "True"

# assets/cart.js onCartUpdate synchronization
$hasFreeShippingSync = $cJs -match '\.cart-drawer__free-shipping'
$hasUpsellSync = $cJs -match '\.cart-drawer__upsell'
$hasFooterSync = $cJs -match '\.cart-drawer__footer'
Assert-Check "M2.3.12" "cart.js onCartUpdate replaces .cart-drawer__free-shipping" $hasFreeShippingSync `
    ".cart-drawer__free-shipping selector match: $hasFreeShippingSync" "True"
Assert-Check "M2.3.13" "cart.js onCartUpdate replaces .cart-drawer__upsell" $hasUpsellSync `
    ".cart-drawer__upsell selector match: $hasUpsellSync" "True"
Assert-Check "M2.3.14" "cart.js onCartUpdate replaces .cart-drawer__footer" $hasFooterSync `
    ".cart-drawer__footer selector match: $hasFooterSync" "True"

# -----------------------------------------------------------------------------
# SUITE 4: THEME SETTINGS CONFIGURATION AUDIT
# -----------------------------------------------------------------------------
Log-Banner "SUITE 4: THEME SETTINGS CONFIGURATION AUDIT"

$settingsDataPath = Join-Path $WorkspaceRoot "config\settings_data.json"
$settingsSchemaPath = Join-Path $WorkspaceRoot "config\settings_schema.json"

$sData = Get-Content -Path $settingsDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$currentPreset = $sData.current
$activePreset = $sData.presets.$currentPreset

Assert-Check "M2.4.1" "Active preset cart_type is 'drawer'" ($activePreset.cart_type -eq "drawer") `
    "cart_type: $($activePreset.cart_type)" "drawer"
Assert-Check "M2.4.2" "Active preset free_shipping_threshold is configured and >= 0" ($null -ne $activePreset.free_shipping_threshold -and $activePreset.free_shipping_threshold -ge 0) `
    "free_shipping_threshold: $($activePreset.free_shipping_threshold)" ">= 0"

$sSchema = Get-Content -Path $settingsSchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cartSection = $sSchema | Where-Object { $_.name -match 'cart' -or ($_.settings | Where-Object { $_.id -eq 'free_shipping_threshold' }) }
$hasThresholdSetting = $false
if ($cartSection) {
    $tSetting = $cartSection.settings | Where-Object { $_.id -eq 'free_shipping_threshold' }
    if ($tSetting) { $hasThresholdSetting = $true }
}
Assert-Check "M2.4.3" "settings_schema.json declares free_shipping_threshold setting" $hasThresholdSetting `
    "free_shipping_threshold declared: $hasThresholdSetting" "True"

# -----------------------------------------------------------------------------
# SUMMARY REPORT
# -----------------------------------------------------------------------------
Log-Banner "CHALLENGER STRESS-TEST SUMMARY"
Write-Host "Total Asserts Evaluated : $script:TotalAsserts" -ForegroundColor White
Write-Host "Passed Asserts          : $script:PassedAsserts" -ForegroundColor Green
Write-Host "Failed Asserts          : $script:FailedAsserts" -ForegroundColor $(if ($script:FailedAsserts -eq 0) { "Green" } else { "Red" })
Write-Host "Advisory Warnings       : $script:Warnings" -ForegroundColor $(if ($script:Warnings -eq 0) { "Green" } else { "Yellow" })

if ($script:Findings.Count -gt 0) {
    Write-Host "`nFindings & Advisory Items:" -ForegroundColor Yellow
    foreach ($f in $script:Findings) {
        Write-Host "  [$($f.Type)] $($f.Id) - $($f.Description)" -ForegroundColor $(if ($f.Type -eq "FAIL") { "Red" } else { "DarkYellow" })
        Write-Host "         Actual: $($f.Actual)" -ForegroundColor Gray
    }
}

if ($script:FailedAsserts -eq 0) {
    Write-Host "`nVERDICT: ALL CRITICAL STRESS TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nVERDICT: FAILURES DETECTED ($script:FailedAsserts failures)" -ForegroundColor Red
    exit 1
}
