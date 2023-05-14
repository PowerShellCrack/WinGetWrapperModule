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

