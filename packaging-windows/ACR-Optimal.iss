; Build with Inno Setup 6 on Windows. This script never touches user data or SAVs.
#define AppVersion "0.1.0"
[Setup]
AppId={{DB79498D-7A35-4B4D-B875-E50AAC3188A3}
AppName=ACR-Optimal
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\ACR-Optimal
DefaultGroupName=ACR-Optimal
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=build
OutputBaseFilename=ACR-Optimal-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
UninstallDisplayName=ACR-Optimal
[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
[Files]
Source: "..\Lancer-ACR-Optimal.bat"; DestDir: "{app}"
Source: "..\interface-windows\*"; DestDir: "{app}\interface-windows"; Flags: recursesubdirs createallsubdirs
Source: "..\ocr-windows\*"; DestDir: "{app}\ocr-windows"; Flags: recursesubdirs createallsubdirs
Source: "..\setup-engineer\*"; DestDir: "{app}\setup-engineer"; Flags: recursesubdirs createallsubdirs
Source: "..\stockage-windows\*"; DestDir: "{app}\stockage-windows"; Flags: recursesubdirs createallsubdirs
Source: "..\collecteur-windows\*"; DestDir: "{app}\collecteur-windows"; Flags: recursesubdirs createallsubdirs
Source: "..\diagnostic-windows\Lancer-Commun.bat"; DestDir: "{app}\diagnostic-windows"
Source: "..\diagnostic-windows\Lire-Sauvegarde-Secteurs.ps1"; DestDir: "{app}\diagnostic-windows"
Source: "..\tests\verify_windows_title_ocr.ps1"; DestDir: "{app}\tests"
[Icons]
Name: "{group}\ACR-Optimal"; Filename: "{app}\Lancer-ACR-Optimal.bat"; WorkingDir: "{app}"
Name: "{userdesktop}\ACR-Optimal"; Filename: "{app}\Lancer-ACR-Optimal.bat"; WorkingDir: "{app}"; Tasks: desktopicon
[Tasks]
Name: desktopicon; Description: "Créer un raccourci sur le Bureau"; Flags: unchecked
; Deliberately no registry, execution-policy, game-file or AppData data deletion sections.
