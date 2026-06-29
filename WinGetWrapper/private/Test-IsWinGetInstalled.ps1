Function Test-IsWinGetInstalled {
    <#
    .SYNOPSIS
        Determines if winget is available

    .DESCRIPTION
        Returns $true when the winget.exe executable can be resolved either on
        the PATH or directly under %ProgramFiles%\WindowsApps. This is more
        reliable than calling 'winget' directly, which fails in SYSTEM context
        (for example during an Autopilot/ESP deployment) where the App Execution
        Alias is not present even though winget is installed.

    .OUTPUTS
        System.Boolean

    .EXAMPLE
        Test-IsWinGetInstalled
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    param()

    return [bool](Resolve-WinGetPath)
}
#endregion
