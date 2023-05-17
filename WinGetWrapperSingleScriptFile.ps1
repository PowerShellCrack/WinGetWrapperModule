
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

Function ConvertFrom-LinesWithDelimiter {
    <#
    .SYNOPSIS
        Converts line with colon delimiter to psobject
    
    .DESCRIPTION
        Converts string output with line with colon delimiter to psobject

    .PARAMETER InputObject
        Specify the input to convert. Accepts input only via the pipeline

    .EXAMPLE 
        ConvertFrom-LinesWithDelimiter -String (winget show --id 'Microsoft.VCRedist.2015+.x64')
    
    .EXAMPLE
        (winget show --id 'Microsoft.VCRedist.2015+.x64') | ConvertFrom-LinesWithDelimiter
    
    .NOTES
    The input is assumed to have line with delimiter 
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] $String,
        [hashtable]$AdditionalProperties,
        [string]$LineDelimiter = ': '
    )
    Begin{
        Set-StrictMode -Version 1
        $Items = @()
    }
    Process{
        
        $obj = New-Object pscustomobject
        foreach ($line in $String -split '\n')
        { 
            if($line.contains($LineDelimiter)){
                #TEST $Property = $AdditionalProperties.GetEnumerator() | Select -first 1
                If($AdditionalProperties.Count -gt 0){
                    Foreach($Property in $AdditionalProperties.GetEnumerator()){
                        $obj | Add-Member -MemberType NoteProperty -Name $Property.Name -Value $Property.Value -Force
                    }
                }
                
                $key = $line.substring(0,$line.indexof($LineDelimiter)).replace(' ','').trim()
                $value = $line.substring($line.indexof($LineDelimiter)+1).trim()
        
                $obj | Add-Member -MemberType NoteProperty -Name $key -Value $value -Force   
            }

        }
        $Items += $obj
    }
    End{
        # Export Items
        Return $Items
    }
}


function ConvertFrom-FixedColumnTable {
    <#
    .SYNOPSIS
        Converts string output to psobject
    
    .DESCRIPTION
        Converts string output in table format (with header) to psobject

    .PARAMETER InputObject
        Specify the input to convert. Accepts input only via the pipeline

    .EXAMPLE
        (winget list) -match '^\p{L}' | ConvertFrom-FixedColumnTable

        This example retrieves all software identified by winget

    .NOTES
        The input is assumed to have a header line whose column names to mark the start of each field
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [String[]]$InputObject
    )
    
    Begin {
        Set-StrictMode -Version 1
        $LineIndex = 0
         # data line
        $List = @()
        $lines = if ($InputObject.Contains("`n")) { $InputObject.TrimEnd("`r", "`n") -split '\r?\n' } else { $InputObject }
    }
    Process {
        Try{
            foreach ($line in $lines) {
                ++$LineIndex
                Write-Verbose ("LINE [{1}]: {0}" -f $line,$LineIndex)
                if($line -match 'Multiple installed packages found matching input criteria. Please refine the input.'){
                    #reset back to 0
                    $LineIndex = 0
                }
                elseif ($LineIndex -eq 1) { 
                    # header line
                    $headerLine = $line
                    # separator line
                    # Get the indices where the fields start.
                    $fieldStartIndex = [regex]::Matches($headerLine, '\b\S').Index
                    # Calculate the field lengths.
                    $fieldLengths = foreach ($i in 1..($fieldStartIndex.Count-1)) { 
                    $fieldStartIndex[$i] - $fieldStartIndex[$i - 1] - 1
                    }
                    # Get the column names
                    $colNames = foreach ($i in 0..($fieldStartIndex.Count-1)) {
                        if ($i -eq $fieldStartIndex.Count-1) {
                            $headerLine.Substring($fieldStartIndex[$i]).Trim()
                        } else {
                            $headerLine.Substring($fieldStartIndex[$i], $fieldLengths[$i]).Trim()
                        }
                    } 
                }else {
                   
                    $i = 0
                    # ordered helper hashtable for object constructions.
                    $ObjectHash = [ordered] @{} 
                    foreach ($colName in $colNames) {
                        Write-Verbose ("COLUMN: {0}" -f $colName)
                        $ObjectHash[$colName] = 
                            if ($fieldStartIndex[$i] -lt $line.Length) {
                                if ($fieldLengths[$i] -and $fieldStartIndex[$i] + $fieldLengths[$i] -le $line.Length) {
                                    $line.Substring($fieldStartIndex[$i], $fieldLengths[$i]).Trim()
                                }
                                else {
                                    $line.Substring($fieldStartIndex[$i]).Trim()
                                }
                            }
                        ++$i
                    }
                    $List += [pscustomobject] $ObjectHash
                }
            }
        }Catch{}
        
    }End{
        # Output list as an object
        Return $List
    }
}


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
        $NewList += $Item -replace '\P{IsBasicLatin}'.Trim()
    }

    #restore encoding settings
    If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
        [Console]::OutputEncoding =  $OriginalEncoding
    }

    Return $NewList
    
}


function Start-WinGetWrapperAppUpdate {
    <#
    .SYNOPSIS
        Upgrades apps to available update

    .PARAMETER Id
        Target a software by its Winget Id. Recommended if need to use Id or Name

    .PARAMETER Name
        Target a software to update by name. Thic can be quirky as some names are long and get cut off in output

    .PARAMETER Silent
        Preforms installation using silent switch

    .PARAMETER Scope
        Options are 'Machine' or 'User'. Defaults to 'Machine'

    .EXAMPLE
        Start-WinGetWrapperAppUpdate

        This example retrieves all software that has an available update sand installs it
    .EXAMPLE
        Get-WinGetWrapperUpgradeList | Select -First 1  | Start-WinGetWrapperAppUpdate

        This example retrieves the first software that has an available update and updates it
    .LINK
        ConvertFrom-FixedColumnTable
        Get-WinGetWapperList
        Test-VSCode
        Test-IsISE
        Get-WinGetWrapperUpgradeList
        Get-WinGetOutput
    #>
    [CmdletBinding(DefaultParameterSetName='Id')]
    param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='Id')]
        [String[]]$Id,

        [Parameter(Mandatory=$False,ParameterSetName='Name')]
        [String]$Name,

        [Boolean]$Silent=$true,

        [ValidateSet('Machine','User')]
        [string]$Scope = "Machine"
    )
    Begin{
        $OriginalEncoding = [Console]::OutputEncoding
        If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        }

        # filter out progress-display and header-separator lines
        $List = Get-WinGetWrapperUpgradeList

        #TEST $Item = $List | Where Available -ne '' | Select -first 1
        Write-Verbose ("Found {0} apps that have available updates" -f $List.count)

        $wingetparam = @()
        

        If ($Silent -eq $true){
            $wingetparam += '--silent'
        }

        #use a defualt paramters for winget upgrade
        $wingetparam += "--scope $($Scope.ToLower())"
        $wingetparam += "--disable-interactivity"
        $wingetparam += "--accept-source-agreements"
        $wingetparam += "--accept-package-agreements"
        $wingetparam += "--force"

        $UpgradeList = @()
    }
    Process{
        [string]$wingetargs = $wingetparam -join " "

        switch($PSCmdlet.ParameterSetName){
            'Name'  { $Items = $List | Where {$_.Name -eq $Name -and $_.Available -ne ''}; $SecondTryUsing = "id"}
            'Id'    { $Items = $List | Where {$_.Id -eq $Id -and $_.Available -ne ''}; $SecondTryUsing = "name" }
        }

        Foreach($Item in $Items){
            
            $obj = New-Object pscustomobject
            $obj | Add-Member -MemberType NoteProperty -Name Name -Value $Item.Name -Force
            $obj | Add-Member -MemberType NoteProperty -Name Id -Value $Item.Id -Force
            Write-Verbose ("Attempting to update app {0}: {1}" -f $PSCmdlet.ParameterSetName, $Item.($PSCmdlet.ParameterSetName))
            switch($PSCmdlet.ParameterSetName){
                'Name'  {
                    Write-Verbose ("RUNNING: winget upgrade --name '{0}' {1}" -f $Item.Name,$wingetargs)
                    $result = Start-Process winget -ArgumentList "upgrade --name `"$($Item.Name)`" $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                }
                'Id'    {
                    Write-Verbose ("RUNNING: winget upgrade --id {0} {1}" -f $Item.Id,$wingetargs)
                    $result = Start-Process winget -ArgumentList "upgrade --id $($Item.Id) $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                }
            }
            $AppOutput = Get-WinGetOutput
            If($AppOutput.Failed){
                Write-Verbose ("Winget failed to upgrade app {0}: {1}" -f $Item.($PSCmdlet.ParameterSetName),$AppOutput.FailedCode)
            }ElseIf($AppOutput.UpgradeNotFound){
                Write-Verbose ("Winget could not find upgrade for app {0}" -f $Item.($PSCmdlet.ParameterSetName))
            }Else{
                Write-Verbose ("Winget app {0} last status is: {1}" -f $Item.($PSCmdlet.ParameterSetName),$AppOutput.LastStatus)
            }
            
            If($AppOutput.AttemptRetry){
                
                Write-Verbose ("Attempting again to update app by {0}: {1}" -f $SecondTryUsing,$Item.Name)
                Write-Verbose ("RUNNING: winget upgrade --$SecondTryUsing '{0}' {1}" -f $Item.Name,$wingetargs)
                $result = Start-Process winget -ArgumentList "upgrade --$SecondTryUsing `"$($Item.Name)`" $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                    -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                $AppOutput = Get-WinGetOutput
                $obj | Add-Member -MemberType NoteProperty -Name ExitCode -Value $result.ExitCode -Force
                $obj | Add-Member -MemberType NoteProperty -Name Status -Value $AppOutput.LastStatus -Force
                $UpgradeList += $obj

            }Else{
                $obj | Add-Member -MemberType NoteProperty -Name ExitCode -Value $result.ExitCode -Force
                $obj | Add-Member -MemberType NoteProperty -Name Status -Value $AppOutput.LastStatus -Force
                $UpgradeList += $obj
            }
        }
            


    }
    End{
        #restore encoding settings
        If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
            [Console]::OutputEncoding =  $OriginalEncoding
        }
        Return $UpgradeList
    }
}

#====================================
# MAIN
#====================================

If(-Not(Test-IsWinGetInstalled)){Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe}

$upgradeableApps = Get-WinGetWrapperUpgradeList

Foreach ($App in $upgradeableApps){
    Start-WinGetWrapperAppUpdate -Id $App.id
}

