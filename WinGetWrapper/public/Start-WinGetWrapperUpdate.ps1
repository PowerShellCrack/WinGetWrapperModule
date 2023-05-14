
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
