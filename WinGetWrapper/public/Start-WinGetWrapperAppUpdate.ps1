
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
