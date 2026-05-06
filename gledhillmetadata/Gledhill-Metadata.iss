; Inno Setup script for Gledhill Metadata (Flutter Windows)
; Build the app first with: flutter build windows --release

#define MyAppName "Gledhill Metadata"
#define MyAppVersion "1.8.0"
#define MyAppPublisher "Gledhill Metadata"
#define MyAppURL "https://nerd-or-geek.github.io/Gledhill-Metadata"
#define MyAppExeName "GledhillMetadata.exe"
#define WebsiteDownloadsDir "..\downloads"
#define WebsiteWindowsInstallerName "Gledhill-Metadata-windows"

[Setup]
AppId={{C614D502-14BD-4276-8841-417CE5D3CB4A}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Export directly to your GitHub Pages downloads folder.
OutputDir={#WebsiteDownloadsDir}
OutputBaseFilename={#WebsiteWindowsInstallerName}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "refreshiconcache"; Description: "Refresh Windows icon cache (recommended if search icon appears stale)"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Package the entire Flutter Windows release bundle.
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; AppUserModelID: "com.nerdorgeek.gledhillmetadata"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; AppUserModelID: "com.nerdorgeek.gledhillmetadata"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
Filename: "{cmd}"; Parameters: "/C ie4uinit.exe -ClearIconCache"; Flags: runhidden postinstall skipifsilent; Tasks: refreshiconcache
