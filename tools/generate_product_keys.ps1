param(
    [ValidateRange(1, 1000)][int]$Count = 3,
    [switch]$Lifetime,
    [ValidateRange(1, 36500)][int]$Days = 30
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputFolder = Join-Path $projectRoot 'generated_keys'
New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
$alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$sha = [Security.Cryptography.SHA256]::Create()
$keys = [Collections.Generic.HashSet[string]]::new()
$rows = [Collections.Generic.List[string]]::new()
$batch = [guid]::NewGuid().ToString('N')
$kind = if ($Lifetime) { 'lifetime' } else { "${Days}dias" }
try {
    while ($keys.Count -lt $Count) {
        $characters = ''
        $byte = [byte[]]::new(1)
        while ($characters.Length -lt 25) {
            $rng.GetBytes($byte)
            $cutoff = 256 - (256 % $alphabet.Length)
            if ($byte[0] -lt $cutoff) { $characters += $alphabet[$byte[0] % $alphabet.Length] }
        }
        $groups = for ($offset = 0; $offset -lt 25; $offset += 5) { $characters.Substring($offset, 5) }
        $key = 'SVP-' + ($groups -join '-')
        if (-not $keys.Add($key)) { continue }
        $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($key))).Replace('-', '').ToLowerInvariant()
        $lifetimeSql = if ($Lifetime) { 'true' } else { 'false' }
        $duration = if ($Lifetime) { 'NULL' } else { "$Days" }
        $rows.Add("('$hash',$duration,$lifetimeSql,'Lote $kind - $batch')")
    }
    $keyPath = Join-Path $outputFolder "keys_${kind}_${batch}.txt"
    $sqlPath = Join-Path $outputFolder "insert_keys_${kind}_${batch}.sql"
    [IO.File]::WriteAllLines($keyPath, [string[]]@($keys), [Text.UTF8Encoding]::new($false))
    $sql = "-- Apply after 202610110002_licenses_v2.sql.`n" +
        "INSERT INTO public.gamerlocker_product_keys (key_hash,duration_days,is_lifetime,label)`nVALUES`n" +
        ($rows -join ",`n") + "`nON CONFLICT (key_hash) DO NOTHING;`n"
    [IO.File]::WriteAllText($sqlPath, $sql, [Text.UTF8Encoding]::new($false))
    Write-Output "Geradas $Count keys $kind. Arquivo: $keyPath"
    Write-Output "SQL de cadastro (ainda nao executado): $sqlPath"
} finally { $rng.Dispose(); $sha.Dispose() }
