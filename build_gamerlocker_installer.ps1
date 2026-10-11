param(
    [string]$ProjectPath = $PSScriptRoot,
    [ValidateSet('release', 'pro')]
    [string]$Channel = 'release',
    [switch]$PrivateUpdates
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectPath

$pubspec = Get-Content .\pubspec.yaml -Raw -Encoding UTF8
$match = [regex]::Match(
    $pubspec,
    '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+\d+)?\s*$'
)

if (-not $match.Success) {
    throw "Nao consegui ler a versao no pubspec.yaml"
}

$version = $match.Groups[1].Value
$updatesRepository = if ($Channel -eq 'pro') { 'GamerLocker/gamerlockerpro-releases' } else { 'GamerLocker/gamerlocker-releases' }
$outputDirectory = if ($Channel -eq 'pro') { 'dist\pro' } else { 'dist' }
if ($PrivateUpdates -and $Channel -ne 'pro') {
    throw "Atualizacoes privadas sao permitidas apenas no canal PRO."
}
$privateUpdatesDefine = if ($PrivateUpdates) { 'true' } else { 'false' }
$appEdition = if ($Channel -eq 'pro') { 'PRO' } else { 'Beta' }

Write-Host ""
Write-Host "GamerLocker v$version" -ForegroundColor Cyan
Write-Host "Executando validacoes..." -ForegroundColor Cyan
Write-Host ""

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Compilando o Steam GC helper atualizado..." -ForegroundColor Cyan
& (Join-Path $ProjectPath "tools\steam_gc_helper\build.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Gerando build Windows Release..." -ForegroundColor Cyan

flutter build windows --release --dart-define-from-file=config/dev.json --dart-define=APP_VERSION=$version --dart-define=UPDATES_REPOSITORY=$updatesRepository --dart-define=PRIVATE_UPDATES=$privateUpdatesDefine
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$exe = ".\build\windows\x64\runner\Release\GamerLocker.exe"

if (-not (Test-Path $exe)) {
    throw "Build terminou, mas nao encontrei $exe"
}

$bundledHelper = ".\build\windows\x64\runner\Release\steam_gc_helper\GamerLocker.SteamGcHelper.exe"
if (-not (Test-Path -LiteralPath $bundledHelper)) {
    throw "Build terminou sem incluir o Steam GC helper: $bundledHelper"
}

# Include the redistributable CRT beside the app for machines without Visual Studio.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere)) {
    throw "Nao encontrei vswhere.exe para localizar o runtime C++ redistribuivel."
}
$vsPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$redistRoot = Join-Path $vsPath "VC\Redist\MSVC"
$crtDirectory = Get-ChildItem -LiteralPath $redistRoot -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object { Get-ChildItem -Path (Join-Path $_.FullName 'x64\Microsoft.VC*.CRT') -Directory } |
    Select-Object -First 1
if (-not $crtDirectory) {
    throw "Nao encontrei o runtime C++ redistribuivel x64."
}
Copy-Item -Path (Join-Path $crtDirectory.FullName '*.dll') -Destination (Split-Path $exe) -Force
foreach ($runtimeDll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path (Split-Path $exe) $runtimeDll))) {
        throw "Runtime C++ ausente no pacote: $runtimeDll"
    }
}

$isccCandidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)

$iscc = $isccCandidates |
    Where-Object { $_ -and (Test-Path $_) } |
    Select-Object -First 1

if (-not $iscc) {
    Write-Host ""
    Write-Host "A build do GamerLocker foi criada com sucesso." -ForegroundColor Green
    Write-Host "Mas o Inno Setup 6 nao foi encontrado." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Instale o Inno Setup 6 e execute este script novamente." -ForegroundColor Yellow
    exit 2
}

New-Item -ItemType Directory -Force .\dist | Out-Null

Write-Host ""
Write-Host "Gerando instalador com Inno Setup..." -ForegroundColor Cyan

& $iscc "/DMyAppVersion=$version" "/DMyAppEdition=$appEdition" "/O$(Join-Path $ProjectPath $outputDirectory)" ".\installer\GamerLocker.iss"

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$setup = Join-Path $outputDirectory "GamerLocker-Setup-v$version-windows-x64.exe"

if (-not (Test-Path $setup)) {
    throw "Inno Setup terminou, mas nao encontrei: $setup"
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "INSTALADOR PRONTO" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host (Resolve-Path $setup)
Write-Host ""
Write-Host "Teste recomendado:" -ForegroundColor Yellow
Write-Host "1. Execute o instalador."
Write-Host "2. Confirme o atalho na Area de Trabalho."
Write-Host "3. Abra o GamerLocker."
Write-Host "4. Feche e abra novamente."
Write-Host "5. Desinstale em Aplicativos instalados e confirme que o cofre continua preservado."
