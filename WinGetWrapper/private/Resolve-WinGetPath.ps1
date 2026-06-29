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
