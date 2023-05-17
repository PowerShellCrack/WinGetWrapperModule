

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