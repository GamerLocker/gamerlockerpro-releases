#ifndef MyAppVersion
  #error MyAppVersion is required. Use build_gamerlocker_installer.ps1.
#endif
#ifndef MyAppEdition
  #define MyAppEdition "Beta"
#endif

#define MyAppName "GamerLocker"
#define MyAppPublisher "GamerLocker"
#define MyAppExeName "GamerLocker.exe"

[Setup]
AppId={{46FB8EDB-DC3C-4B97-9147-F2D994872E17}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion} {#MyAppEdition}
UninstallDisplayName={#MyAppName} {#MyAppVersion} {#MyAppEdition}
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
; Instalacao manual: mostra a opcao de abrir no final.
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir GamerLocker"; Flags: nowait postinstall skipifsilent
; Auto-update: o updater executa o instalador em /VERYSILENT.
; Esta entrada garante que o app seja aberto novamente apos a atualizacao.
Filename: "{app}\{#MyAppExeName}"; Flags: nowait; Check: WizardSilent
