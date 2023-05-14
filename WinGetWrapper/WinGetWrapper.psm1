<#
    DO NOT MODIFY THIS FILE
    The module loads all scripts files into the the run space automatically
    The module manifest will export the public funcions for use
#>
[string]$ResourceRoot = ($PWD.ProviderPath, $PSScriptRoot)[[bool]$PSScriptRoot]

$fileList = (Get-ChildItem -Path "$ResourceRoot\p*" -Directory | Get-ChildItem -File -Filter '*.ps1' -Recurse)

foreach ($file in $fileList  ) {
    Write-Verbose "Loading $($file.FullName)"
    
    . $file.FullName
}

$Global:LogFilePath = ($env:LocalAppData + '\PowerShellCrack\Winget\WingetWrapper_' +  (Get-Date).ToString('yyyy-MM-dd_Thh-mm-ss-tt') + '.log')

If(-Not(Test-IsWinGetInstalled)){Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe}