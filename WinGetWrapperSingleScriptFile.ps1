
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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] $InputObject
    )
    
    Begin {
        Set-StrictMode -Version 1
        $LineIndex = 0
         # data line
        $List = @()
    }
    Process {
        $lines = if ($InputObject.Contains("`n")) { $InputObject.TrimEnd("`r", "`n") -split '\r?\n' } else { $InputObject }
        Try{
            foreach ($line in $lines) {
                ++$LineIndex
                Write-Verbose ("LINE [{1}]: {0}" -f $line,$LineIndex)
                if ($LineIndex -eq 1) { 
                    # header line
                    $headerLine = $line 
                }
                elseif ($LineIndex -eq 2 ) { 
                    
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
                }
                else {
                   
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



function Start-WinGetWrapperAppUpdate {
    <#
    .SYNOPSIS
        Upgrades apps to available update

    .PARAMETER Id
        Target a software by its Winget Id. Recommended if need to use Id or Name

    .PARAMETER Name
        Target a software to update by name. Thic can be quirky as some names are long and get cut off in output

    .PARAMETER All
        Default to this if ID or Name not specficied. WIll attempt to update any software winget has an update for

    .PARAMETER Silent
        Preforms installation using silent switch

    .PARAMETER Scope
        Options are 'Machine' or 'User'. Defaults to 'Machine'

    .EXAMPLE
        Start-WinGetWrapperAppUpdate

        This example retrieves all software that has an available update sand installs it
    .EXAMPLE
        Get-WinGetWrapperUpgradeableList | Select -First 1  | Start-WinGetWrapperAppUpdate

        This example retrieves the first software that has an available update and updates it
    .LINK
        ConvertFrom-FixedColumnTable
        Get-WinGetWapperList
        Test-VSCode
        Test-IsISE
        Get-WinGetWrapperUpgradeableList
    #>
    [CmdletBinding(DefaultParameterSetName='All')]
    param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='Id')]
        [String[]]$Id,

        [Parameter(Mandatory=$False,ParameterSetName='Name')]
        [String]$Name,

        [Parameter(Mandatory=$False,ParameterSetName='All')]
        [switch]$All,

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
        $List =  Get-WinGetWrapperUpgradeableList

        $wingetparam = @()
        

        If ($Silent -eq $true){
            $wingetparam += '--silent'
        }

        $wingetparam += "--scope $($Scope.ToLower())"
        $wingetparam += "--disable-interactivity"
        $wingetparam += "--accept-source-agreements"
        $wingetparam += "--accept-package-agreements"
        $wingetparam += "--force"

        $UpgradeList = @()
    }
    Process{
        [string]$wingetargs = $wingetparam -join " "

        switch($PSBoundParameters.ParameterSetName){
            'Name'  { $Items = $List | Where {$_.Name -eq $Name -and $_.Available -ne ''} }
            'Id'    { $Items = $List | Where {$_.Id -eq $Id -and $_.Available -ne ''} }
            'All'   {$Items = $List | Where Available -ne '' | Select -First 1} # don't need to get full list...just one
            default {$Items = $List | Where Available -ne '' | Select -First 1} # don't need to get full list...just one
        }

        #TEST $Item = $List | Where Available -ne '' | Select -first 1
        
        Foreach($Item in $Items){
            $obj = New-Object pscustomobject
            
            
            switch($PSBoundParameters.ParameterSetName){
                'Name'  {
                    $obj | Add-Member -MemberType NoteProperty -Name Name -Value $Item.Name -Force
                    $obj | Add-Member -MemberType NoteProperty -Name Id -Value $Item.Id -Force
                    Write-Verbose ("RUNNING: winget upgrade --name {0} {1}" -f $Item.Name,$wingetargs)
                    $result = Start-Process winget -ArgumentList "upgrade --name $($Item.Name) $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                }
                'Id'    {
                    $obj | Add-Member -MemberType NoteProperty -Name Name -Value $Item.Name -Force
                    $obj | Add-Member -MemberType NoteProperty -Name Id -Value $Item.Id -Force
                    Write-Verbose ("RUNNING: winget upgrade --id {0} {1}" -f $Item.Id,$wingetargs)
                    $result = Start-Process winget -ArgumentList "upgrade --id $($Item.Id) $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                }
                'All'   {
                    $obj | Add-Member -MemberType NoteProperty -Name AppsUpdated -Value $List.count -Force
                    Write-Verbose ("RUNNING: winget upgrade --all {0}" -f $wingetargs)
                    $result = Start-Process winget -ArgumentList "upgrade --all $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                }
                default {
                    Write-Verbose ("RUNNING: winget upgrade --all {0}" -f $wingetargs)
                    $result = Start-Process winget -ArgumentList "upgrade --all $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                }
            }

            $ExitCode = $result.ExitCode
            $Status = ((Get-Content $env:temp\winget.stdout) -split '`n'| Select -last 3) -join '.'
            $obj | Add-Member -MemberType NoteProperty -Name ExitCode -Value $ExitCode -Force
            $obj | Add-Member -MemberType NoteProperty -Name Status -Value $Status -Force
            $UpgradeList += $obj
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




function Test-WinGetWrapperIsUpgradeable {
    <#
    .SYNOPSIS
        Checks if Winget app has available upddate

    .PARAMETER Details
        Checks if Winget app has available upddate and returns 

    .EXAMPLE
       Get-WinGetWrapperList | Test-WinGetWrapperIsUpgradeable

       This example retrieves all apps that has an available update

    .LINK
        ConvertFrom-FixedColumnTable
        Test-VSCode
        Test-IsISE
        Get-WinGetWrapperUpgradeableList
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
        [string[]] $Id
    )
    Begin{
        $OriginalEncoding = [Console]::OutputEncoding
        If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        }

        #grab list of upgradable apps
        $List = Get-WinGetWrapperUpgradeableList

        $Upgradable = @()
    }
    Process{

        Foreach($Item in $Id){
            $obj = New-Object pscustomobject
            $obj | Add-Member -MemberType NoteProperty -Name Id -Value $Item -Force
            If($List | Where {$_.Available -ne '' -and $_.Id -eq $Item}){
                $obj | Add-Member -MemberType NoteProperty -Name IsUpgradeable -Value $True -Force
            }Else{
                $obj | Add-Member -MemberType NoteProperty -Name IsUpgradeable -Value $False -Force
            }
            
            # filter out first two lines lines
            $Upgradable += $obj
        }
        
    }
    End{
        #restore encoding settings
        If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
            [Console]::OutputEncoding =  $OriginalEncoding
        }

        Return $Upgradable
    }
}

If(-Not(Test-IsWinGetInstalled)){Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe}

Get-WinGetWrapperUpgradeableList | Start-WinGetWrapperAppUpdate