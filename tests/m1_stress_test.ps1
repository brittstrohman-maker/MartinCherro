$ErrorActionPreference = 'Stop'

function Get-RelativeLuminance([string]$hex) {
    $hex = $hex.Trim().TrimStart('#')
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16) / 255.0
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16) / 255.0
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16) / 255.0

    $calc = {
        param($val)
        if ($val -le 0.04045) { return $val / 12.92 }
        else { return [Math]::Pow(($val + 0.055) / 1.055, 2.4) }
    }

    $rLin = &$calc $r
    $gLin = &$calc $g
    $bLin = &$calc $b

    return (0.2126 * $rLin) + (0.7152 * $gLin) + (0.0722 * $bLin)
}

function Get-ContrastRatio([string]$hex1, [string]$hex2) {
    $l1 = Get-RelativeLuminance $hex1
    $l2 = Get-RelativeLuminance $hex2
    $lighter = [Math]::Max($l1, $l2)
    $darker = [Math]::Min($l1, $l2)
    return [Math]::Round(($lighter + 0.05) / ($darker + 0.05), 2)
}

function Get-ComplianceLevel([double]$ratio) {
    if ($ratio -ge 7.0) { return "AAA (Normal & Large)" }
    if ($ratio -ge 4.5) { return "AA (Normal) / AAA (Large)" }
    if ($ratio -ge 3.0) { return "AA (Large & UI Components Only)" }
    return "FAIL (<3.0)"
}

Write-Host "================================================================="
Write-Host "TASK 1: WCAG 2.1 COLOR CONTRAST RATIO AUDIT (5 SCHEMES)"
Write-Host "================================================================="

$settingsJson = Get-Content -Raw "config/settings_data.json" | ConvertFrom-Json
$currentPreset = $settingsJson.current
$schemes = $settingsJson.presets.$currentPreset.color_schemes

$schemeDescriptions = @{
    "scheme-1" = "Warm Ivory Base (#FAF8F5)"
    "scheme-2" = "Forest Green Accent (#2D4030)"
    "scheme-3" = "Deep Charcoal Accent (#1C1D1D)"
    "scheme-4" = "Warm Sand Accent (#D9CBB8)"
    "scheme-5" = "Dark Forest Green Accent (#1E2B20)"
}

$results = @()

foreach ($key in ($schemes.PSObject.Properties.Name | Sort-Object)) {
    $s = $schemes.$key.settings
    $desc = $schemeDescriptions[$key]
    
    $crTextBg = Get-ContrastRatio $s.text $s.background
    $crBtnLabel = Get-ContrastRatio $s.button_label $s.button
    $crSecBtn = Get-ContrastRatio $s.secondary_button_label $s.background
    $crBtnBg = Get-ContrastRatio $s.button $s.background

    $results += [PSCustomObject]@{
        Scheme = "$key ($desc)"
        Element = "Text on Background"
        Foreground = $s.text
        Background = $s.background
        Ratio = $crTextBg
        WCAG_Status = Get-ComplianceLevel $crTextBg
    }
    $results += [PSCustomObject]@{
        Scheme = "$key ($desc)"
        Element = "Button Label on Button"
        Foreground = $s.button_label
        Background = $s.button
        Ratio = $crBtnLabel
        WCAG_Status = Get-ComplianceLevel $crBtnLabel
    }
    $results += [PSCustomObject]@{
        Scheme = "$key ($desc)"
        Element = "Sec Button Label on Bg"
        Foreground = $s.secondary_button_label
        Background = $s.background
        Ratio = $crSecBtn
        WCAG_Status = Get-ComplianceLevel $crSecBtn
    }
    $results += [PSCustomObject]@{
        Scheme = "$key ($desc)"
        Element = "Button fill on Background"
        Foreground = $s.button
        Background = $s.background
        Ratio = $crBtnBg
        WCAG_Status = Get-ComplianceLevel $crBtnBg
    }
}

$results | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "`n================================================================="
Write-Host "TASK 2: RATING STARS SNIPPET EDGE VALUES SIMULATION"
Write-Host "================================================================="

function Simulate-RatingStars($ratingInput, $ratingMaxInput = 5.0) {
    $rating_val = 0.0
    if ($ratingInput -ne $null -and "$ratingInput".Trim() -ne "") {
        $rating_val = [double]$ratingInput
    }

    $max_rating = 5.0
    if ($ratingMaxInput -ne $null -and "$ratingMaxInput".Trim() -ne "") {
        $max_rating = [double]$ratingMaxInput
    }

    if ($rating_val -gt $max_rating) {
        $rating_val = $max_rating
    } elseif ($rating_val -lt 0.0) {
        $rating_val = 0.0
    }

    $rounded_rating = [Math]::Round($rating_val * 2.0, [MidpointRounding]::AwayFromZero) / 2.0
    $max_stars_int = [int][Math]::Round($max_rating, [MidpointRounding]::AwayFromZero)

    $fullStars = 0
    $halfStars = 0
    $emptyStars = 0

    for ($i = 1; $i -le $max_stars_int; $i++) {
        $diff = $rounded_rating - $i
        if ($diff -ge 0) {
            $fullStars++
        } elseif ($diff -eq -0.5) {
            $halfStars++
        } else {
            $emptyStars++
        }
    }

    return [PSCustomObject]@{
        Input = if ($ratingInput -eq $null) { "null" } else { "$ratingInput" }
        ClampedVal = $rating_val
        RoundedVal = $rounded_rating
        FullStars = $fullStars
        HalfStars = $halfStars
        EmptyStars = $emptyStars
        TotalRendered = ($fullStars + $halfStars + $emptyStars)
        ExpectedTotal = $max_stars_int
    }
}

$starTestCases = @(0, 0.1, 0.49, 0.5, 0.99, 1.0, 4.5, 5.0, -1.5, 7.2, $null)
$starResults = @()
foreach ($tc in $starTestCases) {
    $starResults += Simulate-RatingStars $tc
}
$starResults | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "`n================================================================="
Write-Host "TASK 3: PROGRESS BAR SNIPPET EDGE VALUES SIMULATION"
Write-Host "================================================================="

function Simulate-ProgressBar($currentAmount, $targetAmount) {
    $current = if ($currentAmount -ne $null) { [double]$currentAmount } else { 0.0 }
    $target = if ($targetAmount -ne $null) { [double]$targetAmount } else { 0.0 }

    $percentage = 100.0
    if ($target -gt 0) {
        $percentage = [Math]::Round(($current * 100.0) / $target, 1)
    } else {
        $percentage = 100.0
    }

    if ($percentage -gt 100.0) {
        $percentage = 100.0
    } elseif ($percentage -lt 0.0) {
        $percentage = 0.0
    }

    $is_unlocked = $false
    if ($current -ge $target -and $target -gt 0) {
        $is_unlocked = $true
    } elseif ($target -le 0) {
        $is_unlocked = $true
    }

    $remaining = $target - $current
    if ($remaining -lt 0) {
        $remaining = 0
    }

    return [PSCustomObject]@{
        Current = $current
        Target = $target
        Percentage = $percentage
        IsUnlocked = $is_unlocked
        Remaining = $remaining
        AriaValueNow = [Math]::Round($percentage, [MidpointRounding]::AwayFromZero)
    }
}

$progressCases = @(
    @{ Name = "amount=0"; Current = 0; Target = 7500 },
    @{ Name = "amount=threshold"; Current = 7500; Target = 7500 },
    @{ Name = "amount>threshold"; Current = 10000; Target = 7500 },
    @{ Name = "threshold=0"; Current = 5000; Target = 0 },
    @{ Name = "threshold=0, amount=0"; Current = 0; Target = 0 }
)

$progressResults = @()
foreach ($pc in $progressCases) {
    $res = Simulate-ProgressBar $pc.Current $pc.Target
    $progressResults += [PSCustomObject]@{
        Scenario = $pc.Name
        Current = $res.Current
        Target = $res.Target
        Percentage = "$($res.Percentage)%"
        AriaValueNow = $res.AriaValueNow
        IsUnlocked = $res.IsUnlocked
        Remaining = $res.Remaining
    }
}
$progressResults | Format-Table -AutoSize | Out-String | Write-Host