# Change log for WinGetWrapper module

## 1.0.6 June 29, 2026

- Added `Resolve-WinGetPath` to locate winget.exe under `%ProgramFiles%\WindowsApps` so the module works in SYSTEM context (Autopilot/ESP) where the winget alias is not on the PATH
- Rewrote `Test-IsWinGetInstalled` to use the resolver instead of calling `winget` directly (more reliable detection)
- All functions now invoke the resolved winget.exe path rather than the bare `winget` alias
- `ConvertFrom-FixedColumnTable` now skips blank/separator lines and strips progress-spinner / control characters and truncation ellipsis per field for clean output
- Module import no longer throws when winget cannot be registered (warns instead)
- Converted Tests to Pester v5 and added a GitHub Actions workflow to run them
- `WinGetWrapperSingleScriptFile.ps1` is now generated from module source via `Tests\Build-SingleScriptFile.ps1`

## 1.0.5 May 16, 2023

- fixed issue where newly provisioned devices with winget output shows a message; skips message to grab apps
- Changed Get-WinGetWrapperUpgradeList to Get-WinGetWrapperUpgradeList
- Added Get-WinGetVersion. Needed for support different output for each version
- Changed all winget commadn to output to file; this provides less issus with parsing console output and more consistant results
- Updated WinGetWrapperSingleScriptFile.ps1


## 1.0.4 May 14, 2023

- Fixed winget long name unicode ellipsis output; now expand full name and id
- More accurate detection by name when start updgrade; becuse name is no longer shortened
- Double attempt to upgrade app if error with -1978335188; this is due to id not found...but may be found by name
- Split Start-WinGetWrapperAppUpdate into two cmdlets; easier management for updting some or all. 
- Added WingetOuput parser; to get status and clean up other scripts

## 1.0.2 May 13, 2023
- Moved wingetcheck to psm1 file; ensure winget is ready when module is installed

## 1.0.1 May 13, 2023

- Added Winget check; ensure winget hase been initialized; an issue for new machiens that no on has logged in yet

## 0.0.1 May 12, 2023

- Initial module created from scripts
