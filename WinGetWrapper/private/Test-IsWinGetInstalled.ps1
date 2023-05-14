Function Test-IsWinGetInstalled {
    <#
    .SYNOPSIS
    Determines if winget is avialble
    
    .EXAMPLE
    Test-WinGet
    #>
    try {
        winget | Out-null
        return $true
    }
    catch {
        return $false
    }
}
#endregion
