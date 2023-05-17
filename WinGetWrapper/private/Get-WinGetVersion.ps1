Function Get-WinGetVersion {
    Param(
        [Switch]$Literal
    )
    <#
    .SYNOPSIS
    Get the version of Winget
    
    .EXAMPLE
    Get-WinGetVersion
    #>
    $Version = (winget --version)
    If($Literal){
        return [string]($Version -replace '^v')
    }Else{
        return [version]($Version -replace '[^\d.]')
    }
    
}