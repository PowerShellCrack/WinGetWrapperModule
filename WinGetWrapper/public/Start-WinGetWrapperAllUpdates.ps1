
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
        $result = Start-Process winget -ArgumentList "upgrade --all $wingetargs" -PassThru -Wait -WindowStyle Hidden `
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
                    $result = Start-Process winget -ArgumentList "upgrade --name `"$($AppItem.Name)`" $wingetargs" -PassThru -Wait -WindowStyle Hidden `
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
