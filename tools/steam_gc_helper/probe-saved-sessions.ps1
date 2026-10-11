param([switch]$JoinGamerLockerGroup)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$helper = Join-Path $PSScriptRoot 'publish\GamerLocker.SteamGcHelper.exe'
$directory = Join-Path $env:LOCALAPPDATA 'GamerLocker\steam_sessions'
$index = 0
foreach ($file in Get-ChildItem -LiteralPath $directory -Filter '*.bin') {
    $plain = $null
    try {
        $plain = [Security.Cryptography.ProtectedData]::Unprotect(
            [IO.File]::ReadAllBytes($file.FullName), $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $session = [Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json
        $index++
        # No credentials or token are supplied to the process or printed.
        $request = @{username=$session.AccountName; savedSessionOnly=$true; timeoutSeconds=15; joinGamerLockerGroup=[bool]$JoinGamerLockerGroup} | ConvertTo-Json -Compress
        Write-Output "Saved session $index"
        $request | & $helper
    } finally {
        if ($plain) { [Array]::Clear($plain, 0, $plain.Length) }
        $session = $null
        $request = $null
    }
}
