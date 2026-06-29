<#
    .SYNOPSIS
        WinGetWrapper - single script file (no module import required)
    .DESCRIPTION
        This file contains every function from the WinGetWrapper module combined into a
        single script for scenarios where importing a module is not possible (e.g. running
        during Autopilot/ESP in SYSTEM context). It is generated from the module source;
        do not edit by hand - update the module under .\WinGetWrapper and run
        Tests\Build-SingleScriptFile.ps1 to regenerate.
#>

#region FUNCTIONS

#region FUNCTION: Resolve-WinGetPath
Function Resolve-WinGetPath {
    <#
    .SYNOPSIS
        Resolves the full path to the winget.exe executable

    .DESCRIPTION
        winget is normally available on the PATH for an interactive user, but in
        SYSTEM context (for example during an Autopilot/ESP deployment) the App
        Execution Alias is not present. This function resolves the real
        winget.exe inside the Microsoft.DesktopAppInstaller package under
        %ProgramFiles%\WindowsApps so the module works regardless of context.

        The resolved path is cached for the lifetime of the session. Use -Force
        to re-resolve (for example after registering the package).

    .PARAMETER Force
        Ignore the cached value and resolve the path again.

    .OUTPUTS
        System.String. The full path to winget.exe, or $null when it cannot be found.

    .EXAMPLE
        Resolve-WinGetPath

        Returns the full path to winget.exe.

    .EXAMPLE
        & (Resolve-WinGetPath) --version

        Invokes winget directly using the resolved path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$Force
    )

    #return the cached value when it is still valid
    if (-not $Force -and $Script:ResolvedWinGetPath -and (Test-Path -LiteralPath $Script:ResolvedWinGetPath)) {
        Write-Verbose ("Using cached winget path: {0}" -f $Script:ResolvedWinGetPath)
        return $Script:ResolvedWinGetPath
    }

    $WinGetPath = $null

    #1. winget on the PATH (typical interactive user context)
    $Command = Get-Command -Name 'winget.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Command) {
        $WinGetPath = $Command.Source
        Write-Verbose ("Found winget on PATH: {0}" -f $WinGetPath)
    }

    #2. Resolve the executable directly from WindowsApps.
    #   Required for SYSTEM context (Autopilot/ESP) where the winget alias is not on the PATH.
    if (-not $WinGetPath) {
        $AppxRoot = Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsApps'
        if (Test-Path -LiteralPath $AppxRoot) {
            $WinGetPath = Get-ChildItem -Path $AppxRoot -Filter 'winget.exe' -Recurse -Depth 1 -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like '*Microsoft.DesktopAppInstaller_*' } |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -First 1 -ExpandProperty FullName
            if ($WinGetPath) {
                Write-Verbose ("Found winget under WindowsApps: {0}" -f $WinGetPath)
            }
        }
    }

    if ($WinGetPath) {
        $Script:ResolvedWinGetPath = $WinGetPath
    }
    else {
        Write-Verbose "Unable to resolve winget.exe"
    }

    return $WinGetPath
}
#endregion

#region FUNCTION: Test-IsWinGetInstalled
Function Test-IsWinGetInstalled {
    <#
    .SYNOPSIS
        Determines if winget is available

    .DESCRIPTION
        Returns $true when the winget.exe executable can be resolved either on
        the PATH or directly under %ProgramFiles%\WindowsApps. This is more
        reliable than calling 'winget' directly, which fails in SYSTEM context
        (for example during an Autopilot/ESP deployment) where the App Execution
        Alias is not present even though winget is installed.

    .OUTPUTS
        System.Boolean

    .EXAMPLE
        Test-IsWinGetInstalled
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    param()

    return [bool](Resolve-WinGetPath)
}
#endregion
#endregion

#region FUNCTION: Test-IsVsCode
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
#endregion

#region FUNCTION: Test-IsISE
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
#endregion

#region FUNCTION: Get-WinGetVersion
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
    $Version = (& (Resolve-WinGetPath) --version)
    If($Literal){
        return [string]($Version -replace '^v')
    }Else{
        return [version]($Version -replace '[^\d.]')
    }
    
}
#endregion

#region FUNCTION: Get-WinGetOuput
Function Get-WinGetOutput{
    Param(
        $Content = (Get-content $env:temp\winget.stdout),
        [switch]$Passthru,
        [switch]$AsObject
    )

    $obj = New-Object pscustomobject

    If($Passthru)
    {
        If($AsObject)
        {
            $Lines = @()
            Foreach($line in ($Content -split '`n')){
                If( $line -match '^\p{L}'){$Lines += $line}
            }
            $obj | Add-Member -MemberType NoteProperty -Name Output -Value $Lines -Force
            $output = $obj
        }
        Else{
            $output = $Content -match '^\p{L}'
        }
        
    }Else{
        #grabe some known status messages
        $AppFailedCode = $Content | Select -last 2 | Select-String -Pattern '(?<=Installer failed with exit code\: ).+' | Select -Expand Matches | select -expand Value
        $AppUpgradeNotFound = $Content | Select -last 2 | Select-String -Pattern 'No available upgrade found' | Select -Expand Matches | select -expand Value
        $AppVerUnknown = $Content | Select -last 2 | Select-String -Pattern 'version numbers that cannot be determined' | Select -Expand Matches | select -expand Value
        $AppNotFound = $Content | Select -last 2 | Select-String -Pattern 'No installed package found' | Select -Expand Matches | select -expand Value
        $Status = ($Content -split '`n' | Select -last 2)
    
        If($AppFailedCode.Length -gt 0){
            $obj | Add-Member -MemberType NoteProperty -Name Failed -Value $True -Force
            $obj | Add-Member -MemberType NoteProperty -Name FailedCode -Value $AppFailedCode -Force
        }Else{
            $obj | Add-Member -MemberType NoteProperty -Name Failed -Value $False -Force
            $obj | Add-Member -MemberType NoteProperty -Name FailedCode -Value 0 -Force
        }
        
        If($AppUpgradeNotFound.Length -gt 0){
            $obj | Add-Member -MemberType NoteProperty -Name UpgradeNotFound -Value $True -Force 
        }Else{
            $obj | Add-Member -MemberType NoteProperty -Name UpgradeNotFound -Value $False -Force
        }
    
        If($AppNotFound.Length -gt 0){
            $obj | Add-Member -MemberType NoteProperty -Name AppNotFound -Value $True -Force 
        }Else{
            $obj | Add-Member -MemberType NoteProperty -Name AppNotFound -Value $False -Force
        }
    
        If($AppVerUnknown.Length -gt 0){
            $obj | Add-Member -MemberType NoteProperty -Name VersionUnknown -Value $True -Force 
        }Else{
            $obj | Add-Member -MemberType NoteProperty -Name VersionUnknown -Value $False -Force
        }
    
        If($obj.Failed -or $obj.UpgradeNotFound -or $obj.VersionUnknown -or $obj.AppNotFound){
            $obj | Add-Member -MemberType NoteProperty -Name AttemptRetry -Value $True -Force 
        }Else{
            $obj | Add-Member -MemberType NoteProperty -Name AttemptRetry -Value $False -Force
        }
    
        $obj | Add-Member -MemberType NoteProperty -Name LastStatus -Value $Status -Force
        $output = $obj
    }
    

    return $output

}
#endregion

#region FUNCTION: ConvertFrom-LinesWithDelimiter
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
#endregion

#region FUNCTION: ConvertFrom-FixedColumnTable

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
    [OutputType([PSCustomObject])]
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
            foreach ($rawLine in $lines) {
                # NOTE: do not strip characters from the whole line here - the parser
                # relies on fixed column offsets, so removing characters would shift
                # every following column. Cleaning is done per-field after extraction.
                $line = $rawLine

                # Skip blank lines and the dashed header separator line.
                if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*-{3,}\s*$') {
                    continue
                }

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
                <#}
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
                    } #>
                }else {
                   
                    $i = 0
                    # ordered helper hashtable for object constructions.
                    $ObjectHash = [ordered] @{} 
                    foreach ($colName in $colNames) {
                        Write-Verbose ("COLUMN: {0}" -f $colName)
                        $value =
                            if ($fieldStartIndex[$i] -lt $line.Length) {
                                if ($fieldLengths[$i] -and $fieldStartIndex[$i] + $fieldLengths[$i] -le $line.Length) {
                                    $line.Substring($fieldStartIndex[$i], $fieldLengths[$i]).Trim()
                                }
                                else {
                                    $line.Substring($fieldStartIndex[$i]).Trim()
                                }
                            }
                        # strip winget progress-spinner / block-drawing and control
                        # characters plus any truncation ellipsis so every field is clean
                        # (addresses ragged Get-WinGetWrapperList output).
                        if ($null -ne $value) {
                            $value = ($value -replace '[\u2500-\u259F\u2800-\u28FF]' -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]' -replace '\u2026').Trim()
                        }
                        $ObjectHash[$colName] = $value
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
#endregion

#region FUNCTION: Get-WinGetWrapperList

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

    $WinGet = Resolve-WinGetPath
    If(-Not($WinGet)){
        Write-Error "winget is not installed or could not be resolved on this system."
        Return
    }

    Write-Verbose ("Populating list of winget items on system")
    #run winget list and output to file
    $Null = (Start-Process $WinGet -ArgumentList 'list --accept-source-agreements' -PassThru -Wait -WindowStyle Hidden `
        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout)
    # filter out progress-display and header-separator lines
    $List = ConvertFrom-FixedColumnTable -InputObject (Get-WinGetOutput -Passthru) 
    $NewList = @()

    Foreach($Item in $List){
        #some items that output using winget have shortened names displayed in console window.

        #first attempt to expand id by using the name with a winget command that has less data output
        If( ($Item.Id).Length -gt 44 ){
            Write-Verbose ("Expanding app Id: {0}" -f $Item.Id)
            $Null = (Start-Process $WinGet -ArgumentList "list --name `"$($Item.Name)`"" -PassThru -Wait -WindowStyle Hidden `
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
            $Null = (Start-Process $WinGet -ArgumentList "list --id $($Item.Id)" -PassThru -Wait -WindowStyle Hidden `
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
#endregion

#region FUNCTION: Get-WinGetWrapperUpgradeList
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

    $WinGet = Resolve-WinGetPath
    If(-Not($WinGet)){
        Write-Error "winget is not installed or could not be resolved on this system."
        Return
    }

    If((Get-WinGetVersion) -lt [Version]'1.5.1081'){
        #first accept agreement
        $Null = (& $WinGet list --accept-source-agreements)
        $upgradeArgs = 'upgrade'
    }Else{
        $upgradeArgs = 'upgrade --accept-source-agreements'
    }
    
    # filter out progress-display and header-separator lines
    $Null = (Start-Process $WinGet -ArgumentList $upgradeArgs -PassThru -Wait -WindowStyle Hidden `
                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout)
    $List = ConvertFrom-FixedColumnTable -InputObject (Get-WinGetOutput -Passthru) 
    $NewList = @()

    Foreach($Item in $List){
        #some items that output using winget have shortened names and id displayed in console window due to unicode output.
        
        #first attempt to expand id by using the name with a winget command that has less data output
        If( ($Item.Id).Length -gt 44 ){
            Write-Verbose ("Expanding app Id: {0}" -f $Item.Id)
            $Null = (Start-Process $WinGet -ArgumentList "list --name `"$($Item.Name)`"" -PassThru -Wait -WindowStyle Hidden `
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
            $Null = (Start-Process $WinGet -ArgumentList "list --id $($Item.Id)" -PassThru -Wait -WindowStyle Hidden `
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
#endregion

#region FUNCTION: Test-WinGetWrapperIsUpgradeable


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
        Get-WinGetWrapperUpgradeList
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
        $List = Get-WinGetWrapperUpgradeList

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
#endregion

#region FUNCTION: Start-WinGetWrapperAppUpdate

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

        $WinGet = Resolve-WinGetPath
        If(-Not($WinGet)){
            Write-Error "winget is not installed or could not be resolved on this system."
            Return
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
                    $result = Start-Process $WinGet -ArgumentList "upgrade --name `"$($Item.Name)`" $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                }
                'Id'    {
                    Write-Verbose ("RUNNING: winget upgrade --id {0} {1}" -f $Item.Id,$wingetargs)
                    $result = Start-Process $WinGet -ArgumentList "upgrade --id $($Item.Id) $wingetargs" -PassThru -Wait -WindowStyle Hidden `
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
                $result = Start-Process $WinGet -ArgumentList "upgrade --$SecondTryUsing `"$($Item.Name)`" $wingetargs" -PassThru -Wait -WindowStyle Hidden `
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
#endregion

#region FUNCTION: Start-WinGetWrapperAllUpdates

function Start-WinGetWrapperAllUpdates {
    <#
    .SYNOPSIS
        Upgrades all apps

    .PARAMETER Silent
        Preforms installation using silent switch

    .PARAMETER Scope
        Options are 'Machine' or 'User'. Defaults to 'Machine'

    .EXAMPLE
        Start-WinGetWrapperAllUpdates

        This example retrieves all software that has an available update and installs it

    .LINK
        ConvertFrom-FixedColumnTable
        Get-WinGetWapperList
        Test-VSCode
        Test-IsISE
        Get-WinGetWrapperUpgradeList
        Get-WinGetOutput
    #>
    [CmdletBinding()]
    param(
        [Boolean]$Silent=$true,

        [ValidateSet('Machine','User')]
        [string]$Scope = "Machine"
    )
    Begin{
        $OriginalEncoding = [Console]::OutputEncoding
        If(Test-VSCode -eq $false -and Test-IsISE -eq $false){
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        }

        $WinGet = Resolve-WinGetPath
        If(-Not($WinGet)){
            Write-Error "winget is not installed or could not be resolved on this system."
            Return
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
            'Name'  { $Items = $List | Where {$_.Name -eq $Name -and $_.Available -ne ''} }
            'Id'    { $Items = $List | Where {$_.Id -eq $Id -and $_.Available -ne ''} }
        }

        
        $obj = New-Object pscustomobject
        $obj | Add-Member -MemberType NoteProperty -Name Apps -Value $List.count -Force
        Write-Verbose ("RUNNING: winget upgrade --all {0}" -f $wingetargs)
        $result = Start-Process $WinGet -ArgumentList "upgrade --all $wingetargs" -PassThru -Wait -WindowStyle Hidden `
            -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
        
        $AppOutput = Get-WinGetOutput
        If($AppOutput.Failed){
            Write-Verbose ("Winget failed to upgrade all apps: {0}" -f $AppOutput.FailedCode)
        }ElseIf($AppOutput.UpgradeNotFound){
            Write-Verbose ("Winget could not find upgrade for apps")
        }Else{
            Write-Verbose ("Winget all app last status is: {0}" -f $AppOutput.LastStatus)
        }

        If($AppOutput.AttemptRetry -or $result.ExitCode -ne 0){

            #$AppNumbers = $Content | Select-String '\d+/\d+' -AllMatches | Select -Expand Matches | select -expand Value
            For($i = 0; $i -lt $List.Count; $i++)
            {
                $AppItem = $List[$i]
                If($AppItem){
                    Write-Verbose ("[{0}/{1}] Attempting again to update app name: {2}" -f ($AppNum+1),$List.count,$Item.Name)
                    Write-Verbose ("RUNNING: winget upgrade --name '{0}' {1}" -f $AppItem.Name,$wingetargs)
                    $result = Start-Process $WinGet -ArgumentList "upgrade --name `"$($AppItem.Name)`" $wingetargs" -PassThru -Wait -WindowStyle Hidden `
                                        -RedirectStandardError $env:temp\winget.errout -RedirectStandardOutput $env:temp\winget.stdout
                    $AppOutput = Get-WinGetOutput
                    $obj | Add-Member -MemberType NoteProperty -Name ExitCode -Value $result.ExitCode -Force
                    $obj | Add-Member -MemberType NoteProperty -Name Status -Value $AppOutput.LastStatus -Force
                    $UpgradeList += $obj
                }Else{
                    Write-Verbose ("No app found in list")
                }
                
            }

        }Else{
            $obj | Add-Member -MemberType NoteProperty -Name ExitCode -Value $result.ExitCode -Force
            $obj | Add-Member -MemberType NoteProperty -Name Status -Value $AppOutput.LastStatus -Force
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
#endregion
#endregion FUNCTIONS

#====================================
# MAIN
#====================================
If(-Not(Test-IsWinGetInstalled)){
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
}

$upgradeableApps = Get-WinGetWrapperUpgradeList

Foreach ($App in $upgradeableApps){
    Start-WinGetWrapperAppUpdate -Id $App.Id
}

