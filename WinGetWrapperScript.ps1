
Install-Module WinGetWrapper
Import-Module WinGetWrapper

Get-Command -Module WinGetWrapper

Get-WinGetWrapperUpgradeList | Start-WinGetWrapperAppUpdate