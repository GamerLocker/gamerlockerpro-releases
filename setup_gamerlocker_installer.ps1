param(
    [string]$ProjectPath = "C:\Users\junio\Documents\steamvault2"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectPath

$backupRoot = "C:\Users\junio\Documents\gamerlocker_backups"
New-Item -ItemType Directory -Force $backupRoot | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $backupRoot "installer_setup_$stamp"
New-Item -ItemType Directory -Force $backupDir | Out-Null

$cmakePath = Join-Path $ProjectPath "windows\CMakeLists.txt"
$runnerRcPath = Join-Path $ProjectPath "windows\runner\Runner.rc"
$mainCppPath = Join-Path $ProjectPath "windows\runner\main.cpp"
$pubspecPath = Join-Path $ProjectPath "pubspec.yaml"

foreach ($file in @($cmakePath, $runnerRcPath, $mainCppPath, $pubspecPath)) {
    if (-not (Test-Path $file)) {
        throw "Nao encontrei arquivo esperado: $file"
    }

    Copy-Item $file (Join-Path $backupDir ([IO.Path]::GetFileName($file))) -Force
}

# 1) Nome real do executavel Windows: GamerLocker.exe
$cmake = [IO.File]::ReadAllText($cmakePath, [Text.Encoding]::UTF8)
$cmakeNew = [regex]::Replace(
    $cmake,
    'set\s*\(\s*BINARY_NAME\s+"[^"]+"\s*\)',
    'set(BINARY_NAME "GamerLocker")',
    1
)

if ($cmakeNew -eq $cmake -and -not $cmake.Contains('BINARY_NAME "GamerLocker"')) {
    throw "Nao consegui alterar BINARY_NAME em windows\CMakeLists.txt. Backup: $backupDir"
}

[IO.File]::WriteAllText(
    $cmakePath,
    $cmakeNew,
    (New-Object Text.UTF8Encoding($false))
)

# 2) Metadados do EXE
$rc = [IO.File]::ReadAllText($runnerRcPath, [Text.Encoding]::UTF8)

$replacements = @{
    'VALUE "CompanyName", "[^"]*"'       = 'VALUE "CompanyName", "GamerLocker"'
    'VALUE "FileDescription", "[^"]*"'   = 'VALUE "FileDescription", "GamerLocker"'
    'VALUE "InternalName", "[^"]*"'      = 'VALUE "InternalName", "GamerLocker"'
    'VALUE "OriginalFilename", "[^"]*"'  = 'VALUE "OriginalFilename", "GamerLocker.exe"'
    'VALUE "ProductName", "[^"]*"'       = 'VALUE "ProductName", "GamerLocker"'
}

foreach ($pattern in $replacements.Keys) {
    $rc = [regex]::Replace($rc, $pattern, $replacements[$pattern])
}

[IO.File]::WriteAllText(
    $runnerRcPath,
    $rc,
    (New-Object Text.UTF8Encoding($false))
)

# 3) Titulo da janela
$cpp = [IO.File]::ReadAllText($mainCppPath, [Text.Encoding]::UTF8)
$cppNew = [regex]::Replace(
    $cpp,
    'window\.Create\(L"[^"]+"',
    'window.Create(L"GamerLocker"',
    1
)

if ($cppNew -ne $cpp) {
    [IO.File]::WriteAllText(
        $mainCppPath,
        $cppNew,
        (New-Object Text.UTF8Encoding($false))
    )
} elseif (-not $cpp.Contains('window.Create(L"GamerLocker"')) {
    Write-Host "Aviso: nao alterei o titulo em main.cpp; seu template pode usar outro formato." -ForegroundColor Yellow
}

# 4) Projeto do Inno Setup
$installerDir = Join-Path $ProjectPath "installer"
New-Item -ItemType Directory -Force $installerDir | Out-Null

$issPath = Join-Path $installerDir "GamerLocker.iss"

$iss = @'
#ifndef MyAppVersion
  #error MyAppVersion is required. Use build_gamerlocker_installer.ps1.
#endif

#define MyAppName "GamerLocker"
#define MyAppPublisher "GamerLocker"
#define MyAppExeName "GamerLocker.exe"

[Setup]
AppId={{46FB8EDB-DC3C-4B97-9147-F2D994872E17}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion} Beta
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\GamerLocker
DefaultGroupName=GamerLocker
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=GamerLocker-Setup-v{#MyAppVersion}-windows-x64
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
AllowNoIcons=yes
VersionInfoVersion={#MyAppVersion}
VersionInfoProductName={#MyAppName}
VersionInfoDescription=Instalador do GamerLocker
VersionInfoCompany={#MyAppPublisher}

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Area de Trabalho"; GroupDescription: "Atalhos:"; Flags: checkedonce

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
Root: HKCU; Subkey: "Software\Classes\gamerlocker"; ValueType: string; ValueName: ""; ValueData: "URL:GamerLocker Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\gamerlocker"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\gamerlocker\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCU; Subkey: "Software\Classes\gamerlocker\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Icons]
Name: "{autoprograms}\GamerLocker"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\GamerLocker"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir GamerLocker"; Flags: nowait postinstall skipifsilent
Filename: "{app}\{#MyAppExeName}"; Flags: nowait; Check: WizardSilent
'@

[IO.File]::WriteAllText(
    $issPath,
    $iss,
    (New-Object Text.UTF8Encoding($false))
)

# 5) Script de build do instalador
$builderPath = Join-Path $ProjectPath "build_gamerlocker_installer.ps1"

$builder = @'
param(
    [string]$ProjectPath = "C:\Users\junio\Documents\steamvault2"
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

Write-Host ""
Write-Host "GamerLocker v$version" -ForegroundColor Cyan
Write-Host "Executando validacoes..." -ForegroundColor Cyan
Write-Host ""

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dart format .\lib
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Gerando build Windows Release..." -ForegroundColor Cyan

flutter build windows --release --dart-define-from-file=config/dev.json --dart-define=APP_VERSION=$version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$exe = ".\build\windows\x64\runner\Release\GamerLocker.exe"

if (-not (Test-Path $exe)) {
    throw "Build terminou, mas nao encontrei $exe"
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

& $iscc "/DMyAppVersion=$version" ".\installer\GamerLocker.iss"

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$setup = ".\dist\GamerLocker-Setup-v$version-windows-x64.exe"

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
'@

[IO.File]::WriteAllText(
    $builderPath,
    $builder,
    (New-Object Text.UTF8Encoding($false))
)

# 6) Ignorar artefatos gerados
$gitignorePath = Join-Path $ProjectPath ".gitignore"
$gitignore = if (Test-Path $gitignorePath) {
    [IO.File]::ReadAllText($gitignorePath, [Text.Encoding]::UTF8)
} else {
    ""
}

foreach ($line in @("dist/","*.before_*")) {
    if ($gitignore -notmatch "(?m)^$([regex]::Escape($line))$") {
        if ($gitignore.Length -gt 0 -and -not $gitignore.EndsWith("`n")) {
            $gitignore += "`r`n"
        }
        $gitignore += "$line`r`n"
    }
}

[IO.File]::WriteAllText(
    $gitignorePath,
    $gitignore,
    (New-Object Text.UTF8Encoding($false))
)

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "ESTRUTURA DO INSTALADOR CRIADA" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Backup:" -ForegroundColor Cyan
Write-Host $backupDir
Write-Host ""
Write-Host "Criados:" -ForegroundColor Cyan
Write-Host ".\installer\GamerLocker.iss"
Write-Host ".\build_gamerlocker_installer.ps1"
Write-Host ""
Write-Host "Tambem ajustei o Windows para gerar GamerLocker.exe."
Write-Host ""
Write-Host "Agora execute:" -ForegroundColor Yellow
Write-Host "powershell -ExecutionPolicy Bypass -File .\build_gamerlocker_installer.ps1"
