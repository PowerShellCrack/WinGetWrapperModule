function Get-WinGetWrapperUpgradeableList {
    <#
    .SYNOPSIS
        Gets winget upgrade list

    .EXAMPLE
        Get-WinGetWrapperUpgradeableList

        This example retrieves all software identified by winget

    .LINK
        ConvertFrom-FixedColumnTable
        Test-VSCode
        Test-IsISE
    #>
    [CmdletBinding()]
    param(
    )
    $OriginalEncoding = [Console]::OutputEncoding
    If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    }

    # filter out progress-display and header-separator lines
    $List = (winget upgrade --accept-source-agreements) -match '^\p{L}' | ConvertFrom-FixedColumnTable
    $NewList = @()

    #TEST $Item = $List | Where {$_.Name.Length -gt 44} | Select -first 1
    #TEST $Item = $List | Where {$_.Name.Length -gt 44} | Select -last 1
    #TEST $Item = ($List | Where {$_.Name.Length -gt 44})[2]
    Foreach($Item in $List){
        #some items that output using winget have shortened names displayed in console window.
        #need to expand this to grab full name
        If(($Item.Name).Length -gt 44){
            Write-Verbose ("Updating name for item: {0}" -f $Item.Name)
            $ExpandedName = ((winget list --id $Item.Id --exact) -split '`n'| Select -Last 3 | ConvertFrom-FixedColumnTable).Name
        }Else{
            $ExpandedName = $Item.Name
        }
        $NewList += $Item
    }

    #restore encoding settings
    If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
        [Console]::OutputEncoding =  $OriginalEncoding
    }

    Return $NewList
    
}