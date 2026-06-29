<#
    .SYNOPSIS
        Regenerates WinGetWrapperSingleScriptFile.ps1 from the module source.
    .DESCRIPTION
        Concatenates every private and public function in .\WinGetWrapper into the
        standalone single-file script so it always mirrors the module. Run this after
        changing any module function.
    .EXAMPLE
        .\Tests\Build-SingleScriptFile.ps1
#>
$root = Split-Path -Path $PSScriptRoot -Parent
$mod  = Join-Path $root 'WinGetWrapper'
$out  = Join-Path $root 'WinGetWrapperSingleScriptFile.ps1'

$privOrder = 'Resolve-WinGetPath.ps1','Test-IsWinGetInstalled.ps1','Test-IsVsCode.ps1','Test-IsISE.ps1','Get-WinGetVersion.ps1','Get-WinGetOuput.ps1','ConvertFrom-LinesWithDelimiter.ps1','ConvertFrom-FixedColumnTable.ps1'
$pubOrder  = 'Get-WinGetWrapperList.ps1','Get-WinGetWrapperUpgradeList.ps1','Test-WinGetWrapperIsUpgradeable.ps1','Start-WinGetWrapperAppUpdate.ps1','Start-WinGetWrapperAllUpdates.ps1'

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<#')
[void]$sb.AppendLine('    .SYNOPSIS')
[void]$sb.AppendLine('        WinGetWrapper - single script file (no module import required)')
[void]$sb.AppendLine('    .DESCRIPTION')
[void]$sb.AppendLine('        This file contains every function from the WinGetWrapper module combined into a')
[void]$sb.AppendLine('        single script for scenarios where importing a module is not possible (e.g. running')
[void]$sb.AppendLine('        during Autopilot/ESP in SYSTEM context). It is generated from the module source;')
[void]$sb.AppendLine('        do not edit by hand - update the module under .\WinGetWrapper and run')
[void]$sb.AppendLine('        Tests\Build-SingleScriptFile.ps1 to regenerate.')
[void]$sb.AppendLine('#>')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('#region FUNCTIONS')

foreach ($f in ($privOrder + $pubOrder)) {
    $path = if ($privOrder -contains $f) { Join-Path $mod "private\$f" } else { Join-Path $mod "public\$f" }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("#region FUNCTION: $($f -replace '\.ps1$')")
    [void]$sb.AppendLine(((Get-Content -LiteralPath $path -Raw).TrimEnd()))
    [void]$sb.AppendLine('#endregion')
}
[void]$sb.AppendLine('#endregion FUNCTIONS')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('#====================================')
[void]$sb.AppendLine('# MAIN')
[void]$sb.AppendLine('#====================================')
[void]$sb.AppendLine('If(-Not(Test-IsWinGetInstalled)){')
[void]$sb.AppendLine('    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe')
[void]$sb.AppendLine('}')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('$upgradeableApps = Get-WinGetWrapperUpgradeList')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Foreach ($App in $upgradeableApps){')
[void]$sb.AppendLine('    Start-WinGetWrapperAppUpdate -Id $App.Id')
[void]$sb.AppendLine('}')

Set-Content -LiteralPath $out -Value $sb.ToString() -Encoding UTF8
Write-Output "Wrote $out ($((Get-Content $out).Count) lines)"
