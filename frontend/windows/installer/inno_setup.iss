; =====================================================================
; INNO SETUP SCRIPT FOR CHATGUARD WINDOWS SETUP WIZARD
; Creates a standard "Next > Next > Install > Finish" Windows Installer
; =====================================================================

#define MyAppName "ChatGuard"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "ChatGen Team"
#define MyAppURL "https://two6-11-3-chat.onrender.com"
#define MyAppExeName "frontend.exe"
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
OutputBaseFilename=chatguard-windows-setup
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
; Main Executable
Source: "{#MyAppSourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; All Flutter Runtime Dependencies (flutter_windows.dll, data folder, plugins)
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu Shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startmenuicon; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; Desktop Shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
; Option to launch ChatGuard immediately after installation finishes
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
