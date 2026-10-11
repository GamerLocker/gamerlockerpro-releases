param([switch]$JoinGamerLockerGroup, [switch]$AccountDetails, [switch]$Classification)
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
        $request = @{username=$session.AccountName; savedSessionOnly=$true; timeoutSeconds=15; joinGamerLockerGroup=[bool]$JoinGamerLockerGroup; detailsOnly=[bool]$AccountDetails} | ConvertTo-Json -Compress
        Write-Output "Saved session $index"
        if ($AccountDetails) {
            $response = ($request | & $helper) | ConvertFrom-Json
            [pscustomobject]@{Status=$response.status; GamesStatus=$response.accountDetails.gamesStatus;
                Games=@($response.accountDetails.games).Count; Level=$response.accountDetails.steamLevel;
                BadgesStatus=$response.accountDetails.badgesStatus; Badges=@($response.accountDetails.badges).Count;
                InventoryStatus=$response.accountDetails.inventoryStatus; Items=@($response.accountDetails.inventory).Count;
                Complete=$response.accountDetails.inventoryComplete}
        } elseif ($Classification) {
            $response = ($request | & $helper) | ConvertFrom-Json
            [pscustomobject]@{Status=$response.status; Cs2Level=$response.cs2Level;
                Prime=$response.prime; VacBanned=$response.vacBanned; PenaltySeconds=$response.penaltySeconds}
        } else { $request | & $helper }
    } finally {
        if ($plain) { [Array]::Clear($plain, 0, $plain.Length) }
        $session = $null
        $request = $null
    }
}
