Function Test-IsISE {
    <#
    .SYNOPSIS
    Determines if script running in ISE
    
    .EXAMPLE
    Test-IsISE
    #>
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

