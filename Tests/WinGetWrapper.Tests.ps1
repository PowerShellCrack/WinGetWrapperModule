#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Pester v5 tests for the WinGetWrapper module.

    These tests exercise the parsing / detection logic without requiring a real
    winget installation. External calls to winget are mocked so the suite can run
    on any Windows runner (including GitHub Actions).
#>

BeforeAll {
    $script:ModuleRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\WinGetWrapper'
    $script:Manifest   = Join-Path -Path $script:ModuleRoot -ChildPath 'WingetWrapper.psd1'

    Import-Module $script:Manifest -Force -ErrorAction Stop

    # Builds a fixed-width table line so column offsets line up exactly with the header.
    function script:New-FixedRow {
        param([string[]]$Values, [int[]]$Widths)
        $sb = ''
        for ($i = 0; $i -lt $Values.Count; $i++) {
            if ($i -eq $Values.Count - 1) {
                $sb += $Values[$i]
            }
            else {
                $sb += $Values[$i].PadRight($Widths[$i])
            }
        }
        return $sb
    }

    $script:Widths = 24, 30, 16, 16
    $script:SampleListLines = @(
        (New-FixedRow -Values @('Name', 'Id', 'Version', 'Source')             -Widths $script:Widths)
        '------------------------------------------------------------------------------'
        (New-FixedRow -Values @('Microsoft Edge', 'Microsoft.Edge', '120.0.1', 'winget') -Widths $script:Widths)
        (New-FixedRow -Values @('Windows SDK', 'Microsoft.WindowsSDK', '10.0.22000', 'winget') -Widths $script:Widths)
    )
}

AfterAll {
    Remove-Module WingetWrapper -Force -ErrorAction SilentlyContinue
}

Describe 'Module manifest and exports' {
    It 'has a valid manifest' {
        { Test-ModuleManifest -Path $script:Manifest -ErrorAction Stop } | Should -Not -Throw
    }

    It 'exports the documented public commands' {
        $expected = @(
            'Get-WinGetWrapperList'
            'Get-WinGetWrapperUpgradeList'
            'Test-WinGetWrapperIsUpgradeable'
            'Start-WinGetWrapperAppUpdate'
            'Start-WinGetWrapperAllUpdates'
        )
        $exported = (Get-Command -Module WingetWrapper).Name
        foreach ($cmd in $expected) {
            $exported | Should -Contain $cmd
        }
    }
}

Describe 'ConvertFrom-FixedColumnTable' {
    It 'parses a winget-style fixed-column table into objects' {
        InModuleScope WingetWrapper -Parameters @{ Lines = $script:SampleListLines } {
            param($Lines)
            $result = ConvertFrom-FixedColumnTable -InputObject $Lines
            $result.Count | Should -Be 2
            $result[0].Name | Should -Be 'Microsoft Edge'
            $result[0].Id   | Should -Be 'Microsoft.Edge'
            $result[1].Id   | Should -Be 'Microsoft.WindowsSDK'
        }
    }

    It 'skips the dashed separator and whitespace-only lines' {
        InModuleScope WingetWrapper -Parameters @{ Lines = $script:SampleListLines } {
            param($Lines)
            $padded = @($Lines[0], '   ', $Lines[1], $Lines[2], '      ', $Lines[3])
            $result = ConvertFrom-FixedColumnTable -InputObject $padded
            $result.Count | Should -Be 2
            $result.Id | Should -Not -Contain ''
        }
    }

    It 'strips progress-spinner / control characters and ellipsis from values' {
        InModuleScope WingetWrapper {
            $widths = 24, 30, 16, 16
            $header = 'Name'.PadRight(24) + 'Id'.PadRight(30) + 'Version'.PadRight(16) + 'Source'
            $dirty  = ("Mic$([char]0x2588)rosoft$([char]0x2026)".PadRight(24)) + 'Microsoft.Edge'.PadRight(30) + '120.0.1'.PadRight(16) + 'winget'
            $result = ConvertFrom-FixedColumnTable -InputObject @($header, $dirty)
            $result[0].Name | Should -Not -Match '[\u2500-\u259F\u2026]'
            $result[0].Id   | Should -Be 'Microsoft.Edge'
        }
    }
}

Describe 'ConvertFrom-LinesWithDelimiter' {
    It 'parses key/value lines into a single object' {
        InModuleScope WingetWrapper {
            $show = @(
                'Found Microsoft Visual C++ [Microsoft.VCRedist.2015+.x64]'
                'Version: 14.34.31938.0'
                'Publisher: Microsoft Corporation'
                'Homepage: https://visualstudio.microsoft.com/'
            ) -join "`n"
            $obj = ConvertFrom-LinesWithDelimiter -String $show
            $obj.Version   | Should -Be '14.34.31938.0'
            $obj.Publisher | Should -Be 'Microsoft Corporation'
            $obj.Homepage  | Should -Be 'https://visualstudio.microsoft.com/'
        }
    }

    It 'merges AdditionalProperties into the object' {
        InModuleScope WingetWrapper {
            $obj = ConvertFrom-LinesWithDelimiter -String "Version: 1.0.0`n" -AdditionalProperties @{ Id = 'Test.App' }
            $obj.Id      | Should -Be 'Test.App'
            $obj.Version | Should -Be '1.0.0'
        }
    }
}

Describe 'Resolve-WinGetPath' {
    It 'returns the path found on the PATH' {
        InModuleScope WingetWrapper {
            $Script:ResolvedWinGetPath = $null
            Mock Get-Command -ParameterFilter { $Name -eq 'winget.exe' } -MockWith {
                [pscustomobject]@{ Source = 'C:\Path\winget.exe' }
            }
            Mock Test-Path { $true }
            Resolve-WinGetPath -Force | Should -Be 'C:\Path\winget.exe'
        }
    }

    It 'falls back to WindowsApps when not on the PATH' {
        InModuleScope WingetWrapper {
            $Script:ResolvedWinGetPath = $null
            Mock Get-Command -ParameterFilter { $Name -eq 'winget.exe' } -MockWith { $null }
            Mock Test-Path { $true }
            Mock Get-ChildItem {
                [pscustomobject]@{
                    FullName      = 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.0_x64__8wekyb3d8bbwe\winget.exe'
                    LastWriteTime = (Get-Date)
                }
            }
            Resolve-WinGetPath -Force | Should -Match 'Microsoft.DesktopAppInstaller_.*winget\.exe$'
        }
    }

    It 'returns $null when winget cannot be found anywhere' {
        InModuleScope WingetWrapper {
            $Script:ResolvedWinGetPath = $null
            Mock Get-Command -ParameterFilter { $Name -eq 'winget.exe' } -MockWith { $null }
            Mock Test-Path { $false }
            Resolve-WinGetPath -Force | Should -BeNullOrEmpty
        }
    }
}

Describe 'Test-IsWinGetInstalled' {
    It 'returns $true when a winget path is resolved' {
        InModuleScope WingetWrapper {
            Mock Resolve-WinGetPath { 'C:\Path\winget.exe' }
            Test-IsWinGetInstalled | Should -BeTrue
        }
    }

    It 'returns $false when no winget path is resolved' {
        InModuleScope WingetWrapper {
            Mock Resolve-WinGetPath { $null }
            Test-IsWinGetInstalled | Should -BeFalse
        }
    }
}
