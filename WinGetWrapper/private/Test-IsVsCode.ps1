#region FUNCTION: Check if running in Visual Studio Code
Function Test-VSCode{
    <#
    .SYNOPSIS
    Determines if script running in VScode
    
    .EXAMPLE
    Test-VSCode
    #>
    if($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else{
        return $false;
    }
}
#endregion