param([switch]$JoinGamerLockerGroup, [switch]$AccountDetails, [switch]$Classification, [switch]$Security, [switch]$Contacts)
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
        if ($Contacts) {
            $response = ($request | & $helper) | ConvertFrom-Json
            [pscustomobject]@{Status=$response.status; EmailPresent=[bool]$response.linkedEmail;
                PhonePresent=[bool]$response.linkedPhone; PremierRating=$response.premierRating}
        } elseif ($Security) {
            $response = ($request | & $helper) | ConvertFrom-Json
            [pscustomobject]@{Status=$response.status; SteamGuard=$response.security.steamGuard;
                TwoFactor=$response.security.twoFactor; EmailVerified=$response.security.emailVerified;
                PhoneVerified=$response.security.phoneVerified}
        } elseif ($AccountDetails) {
            $response = ($request | & $helper) | ConvertFrom-Json
            [pscustomobject]@{Status=$response.status; GamesStatus=$response.accountDetails.gamesStatus;
                Games=@($response.accountDetails.games).Count; Level=$response.accountDetails.steamLevel;
                BadgesStatus=$response.accountDetails.badgesStatus; Badges=@($response.accountDetails.badges).Count;
                InventoryStatus=$response.accountDetails.inventoryStatus; Items=@($response.accountDetails.inventory).Count;
                Complete=$response.accountDetails.inventoryComplete}
        } elseif ($Classification) {
            $response = ($request | & $helper) | ConvertFrom-Json
            [pscustomobject]@{Status=$response.status; Cs2Level=$response.cs2Level;
                Prime=$response.prime; VacBanned=$response.vacBanned; PenaltySeconds=$response.penaltySeconds;
                PenaltyReason=$response.penaltyReason}
        } else {
            $response = ($request | & $helper) | ConvertFrom-Json
            $response.PSObject.Properties.Remove('linkedEmail')
            $response.PSObject.Properties.Remove('linkedPhone')
            $response | ConvertTo-Json -Depth 10 -Compress
        }
    } finally {
        if ($plain) { [Array]::Clear($plain, 0, $plain.Length) }
        $session = $null
        $request = $null
    }
}
