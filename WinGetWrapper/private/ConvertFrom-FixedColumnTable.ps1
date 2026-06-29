
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
