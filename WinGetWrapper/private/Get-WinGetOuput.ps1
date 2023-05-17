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