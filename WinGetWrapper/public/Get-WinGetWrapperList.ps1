
function Get-WinGetWrapperList {
    <#
    .SYNOPSIS
        Gets winget list 

    .PARAMETER Details
        Get details of Winget app. This can take longer to process

    .EXAMPLE
         Get-WinGetWrapperList

        This example retrieves all software identified by winget

    .LINK
        ConvertFrom-FixedColumnTable
        Test-VSCode
        Test-IsISE
    #>
    [CmdletBinding()]
    param(
        [Switch] $Details
    )
    $OriginalEncoding = [Console]::OutputEncoding
    If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    }
    

    Write-Verbose ("Populating list of winget items on system")
    # filter out progress-display and header-separator lines
    $List = (winget list --accept-source-agreements) -match '^\p{L}' | ConvertFrom-FixedColumnTable
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

        #Build newlist. If details need, collection that list
        Write-Verbose ("Details can take some time...")
        If($Details){
            $NewList += ConvertFrom-LinesWithDelimiter -String (winget show --id $Item.Id --exact) `
                                                    -AdditionalProperties @{
                                                        Name = $ExpandedName
                                                        Id = $Item.Id
                                                        CurrentVersion = $Item.Version
                                                        InstallSource = $Item.Source
                                                    } | 
                                                    Select -First 1
        }Else{
            $NewList += $Item
        }
    }

    #restore encoding settings
    If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
        [Console]::OutputEncoding =  $OriginalEncoding
    }

    Return $NewList
    
}


