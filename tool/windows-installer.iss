; Inno Setup script for the Windows installer.
; Build with:  iscc tool\windows-installer.iss /DAppVersion=0.1.0
; Expects:     flutter build windows --release  (build\windows\x64\runner\Release)
; Produces:    build\dist\xtream-player-<version>-windows-x64-setup.exe

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

#define AppName "Orion Player"
#define AppPublisher "dcenhance"
#define AppURL "https://github.com/dcenhance/xt_client_flutter"
#define AppExe "xtream_player.exe"
#define SourceDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8E1B4C42-7E5A-4C0E-9E3B-2B7A5C1D9F10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir=..\build\dist
OutputBaseFilename=xtream-player-{#AppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
UninstallDisplayIcon={app}\{#AppExe}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startmenu"; Description: "Create a Start Menu entry"

[Files]
; every file the Flutter runner needs, including the libmpv DLL from media_kit
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Tasks: startmenu
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent