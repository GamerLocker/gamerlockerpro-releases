$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Publish = Join-Path $Root "publish"
$Bundle = Join-Path (Split-Path -Parent (Split-Path -Parent $Root)) "windows\steam_gc_helper"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET SDK 8 nao encontrado. Instale o .NET 8 SDK e execute este script novamente."
}

# Verify generated directory targets before recursively replacing them.
$ProjectRoot = [IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $Root)))
$ProjectPrefix = $ProjectRoot.TrimEnd('\') + '\'
foreach ($Target in @($Publish, $Bundle)) {
    $ResolvedTarget = [IO.Path]::GetFullPath($Target)
    if (-not $ResolvedTarget.StartsWith($ProjectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Pasta de build fora do projeto: $ResolvedTarget"
    }
}
Remove-Item -LiteralPath $Publish -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $Bundle -Recurse -Force -ErrorAction SilentlyContinue

dotnet publish (Join-Path $Root "GamerLocker.SteamGcHelper.csproj") `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $Publish

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao compilar o Steam GC helper (dotnet publish retornou $LASTEXITCODE)."
}

if (-not (Test-Path $Publish)) {
    throw "Compilacao terminou sem gerar a pasta de publish: $Publish"
}

New-Item -ItemType Directory -Force -Path $Bundle | Out-Null
Copy-Item (Join-Path $Publish "*") $Bundle -Recurse -Force

Write-Host "Steam GC helper pronto em: $Bundle"
