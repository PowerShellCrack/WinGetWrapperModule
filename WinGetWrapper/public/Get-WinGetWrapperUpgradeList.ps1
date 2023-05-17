function Get-WinGetWrapperUpgradeList {
    <#
    .SYNOPSIS
        Gets winget upgrade list

    .EXAMPLE
        Get-WinGetWrapperUpgradeList

        This example retrieves all software identified by winget

    .LINK
        ConvertFrom-FixedColumnTable
        Test-VSCode
        Test-IsISE
        Get-WinGetVersion
        Get-WinGetOutput
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
 
    $OriginalEncoding = [Console]::OutputEncoding
    If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    }

    If((Get-WinGetVersion) -lt [Version]'1.5.1081'){
        #first accept agreement
        $Null = (winget list --accept-source-agreements)
        $upgradeArgs = 'upgrade'
    }Else{
        $upgradeArgs = 'upgrade --accept-source-agreements'
    }
    
    # filter out progress-display and header-separator lines
    $Null = (Start-Process winget -ArgumentList $upgradeArgs -PassThru -Wait -WindowStyle Hidden `
                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout)
    $List = ConvertFrom-FixedColumnTable -InputObject (Get-WinGetOutput -Passthru) 
    $NewList = @()

    Foreach($Item in $List){
        #some items that output using winget have shortened names and id displayed in console window due to unicode output.
        
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