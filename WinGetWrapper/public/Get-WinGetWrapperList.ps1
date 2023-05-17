
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
        Get-WinGetOutput
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Switch] $Details
    )
    $OriginalEncoding = [Console]::OutputEncoding
    If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    }
    

    Write-Verbose ("Populating list of winget items on system")
    #run winget list and output to file
    $Null = (Start-Process winget -ArgumentList 'list --accept-source-agreements' -PassThru -Wait -WindowStyle Hidden `
        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout)
    # filter out progress-display and header-separator lines
    $List = ConvertFrom-FixedColumnTable -InputObject (Get-WinGetOutput -Passthru) 
    $NewList = @()

    Foreach($Item in $List){
        #some items that output using winget have shortened names displayed in console window.

        #first attempt to expand id by using the name with a winget command that has less data output
        If( ($Item.Id).Length -gt 44 ){
            Write-Verbose ("Expanding app Id: {0}" -f $Item.Id)
            $Null = (Start-Process winget -ArgumentList "list --name `"$($Item.Name)`"" -PassThru -Wait -WindowStyle Hidden `
                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout)
            $Expanded = ConvertFrom-FixedColumnTable -InputObject (Get-WinGetOutput -Passthru)
            #$Expanded = ((winget list --name $Item.Name) -split '`n'| Select -Last 3 | ConvertFrom-FixedColumnTable)
            $ExpandedMatch = $Expanded | Where Name -eq $Item.Name
            $Item.Name = $Expanded.Name -replace '\P{IsBasicLatin}'.Trim()
            $Item.Id = $Expanded.Id -replace '\P{IsBasicLatin}'.Trim()
        }
        
        #if id expanasion doesn't expand name as well, attempt that by using hte already expanded Id
        If( ($Item.Name).Length -gt 44 ){
            Write-Verbose ("Expanding app Name: {0}" -f $Item.Name)
            $Null = (Start-Process winget -ArgumentList "list --id $($Item.Id)" -PassThru -Wait -WindowStyle Hidden `
                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout)
            $Expanded =  ConvertFrom-FixedColumnTable -InputObject (Get-WinGetOutput -Passthru)
            #$Expanded = ((winget list --id $Item.Id --exact) -split '`n'| Select -Last 3 | ConvertFrom-FixedColumnTable)
            $Item.Name = $Expanded.Name #-replace '-\P{IsBasicLatin}'.Trim()
        }Else{
            $Item.Name = $Item.Name -replace '\P{IsBasicLatin}'.Trim()
        }
        #collect item to list
        $NewList += $Item
    }

    #restore encoding settings
    If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
        [Console]::OutputEncoding =  $OriginalEncoding
    }

    Return $NewList
    
}


