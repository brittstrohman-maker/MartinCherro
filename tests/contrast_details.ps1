function Blend-Color($fgHex, $bgHex, $alpha = 0.75) {
    $fgHex = $fgHex.Trim().TrimStart('#')
    $bgHex = $bgHex.Trim().TrimStart('#')
    $rFg = [Convert]::ToInt32($fgHex.Substring(0, 2), 16)
    $gFg = [Convert]::ToInt32($fgHex.Substring(2, 2), 16)
    $bFg = [Convert]::ToInt32($fgHex.Substring(4, 2), 16)

    $rBg = [Convert]::ToInt32($bgHex.Substring(0, 2), 16)
    $gBg = [Convert]::ToInt32($bgHex.Substring(2, 2), 16)
    $bBg = [Convert]::ToInt32($bgHex.Substring(4, 2), 16)

    $rEff = [int][Math]::Round(($alpha * $rFg) + ((1.0 - $alpha) * $rBg))
    $gEff = [int][Math]::Round(($alpha * $gFg) + ((1.0 - $alpha) * $gBg))
    $bEff = [int][Math]::Round(($alpha * $bFg) + ((1.0 - $alpha) * $bBg))

    return "#{0:X2}{1:X2}{2:X2}" -f $rEff, $gEff, $bEff
}

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
    if ($ratio -ge 3.0) { return "AA (Large & UI Non-text Only)" }
    return "FAIL (<3.0)"
}

$settingsJson = Get-Content -Raw "config/settings_data.json" | ConvertFrom-Json
$currentPreset = $settingsJson.current
$schemes = $settingsJson.presets.$currentPreset.color_schemes

Write-Host "=== 75% OPACITY BODY TEXT (Dawn line 124) ==="
foreach ($key in ($schemes.PSObject.Properties.Name | Sort-Object)) {
    $s = $schemes.$key.settings
    $blendedText = Blend-Color $s.text $s.background 0.75
    $cr75 = Get-ContrastRatio $blendedText $s.background
    Write-Host "$key : Blended Text $blendedText on Bg $($s.background) = $cr75 : 1 -> $(Get-ComplianceLevel $cr75)"
}

Write-Host "`n=== ACCENTS ON BACKGROUNDS ==="
$accent1 = "#2D4030" # Muted Forest Green
$accent2 = "#D9CBB8" # Warm Sand
foreach ($key in ($schemes.PSObject.Properties.Name | Sort-Object)) {
    $s = $schemes.$key.settings
    $crAcc1 = Get-ContrastRatio $accent1 $s.background
    $crAcc2 = Get-ContrastRatio $accent2 $s.background
    Write-Host "$key (Bg: $($s.background)):"
    Write-Host "   Accent 1 ($accent1): $crAcc1 : 1 -> $(Get-ComplianceLevel $crAcc1)"
    Write-Host "   Accent 2 ($accent2): $crAcc2 : 1 -> $(Get-ComplianceLevel $crAcc2)"
}