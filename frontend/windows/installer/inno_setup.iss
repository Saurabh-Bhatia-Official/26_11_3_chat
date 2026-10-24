; =====================================================================
; INNO SETUP SCRIPT FOR WHISPER WINDOWS SETUP WIZARD
; Creates a standard "Next > Next > Install > Finish" Windows Installer
; =====================================================================

#define MyAppName "Whisper"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Whisper Team"
#define MyAppURL "https://whisper-7a0e.onrender.com"
#define MyAppExeName "Whisper.exe"
#define MyAppSourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
; AppId uniquely identifies this application in the Windows Registry
AppId={{D37E5244-8846-4B82-9D74-9C51D2EA5837}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Default installation directory (User AppData or Program Files)
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes

; Output settings
OutputDir=..\..\..\artifacts\windows
OutputBaseFilename=whisper-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Modern Wizard UI ("Next > Next > Install > Finish")
WizardStyle=modern
WizardSizePercent=100
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

; Privilege elevation: Defaults to current user (no admin prompt required), but allows all-users override
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; Uninstallation cleanups
UninstallFilesDir={app}\uninstall

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startmenuicon"; Description: "Create a Start Menu shortcut"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main Executable installed as Whisper.exe
Source: "{#MyAppSourceDir}\frontend.exe"; DestDir: "{app}"; DestName: "{#MyAppExeName}"; Flags: ignoreversion
; All Flutter Runtime Dependencies (flutter_windows.dll, data folder, plugins)
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Excludes: "frontend.exe"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu Shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startmenuicon; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; Desktop Shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
; Option to launch Whisper immediately after installation finishes
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
