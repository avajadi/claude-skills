; Inno Setup script for the Windows installer: VST3 (and CLAP) into the standard system plug-in folders, which hosts
; scan by default. release-windows.yml passes every define from packaging/plugin.env; by hand:
;
;   iscc /DAppVersion=1.0.0 "/DAppName=My Plugin" "/DPublisher=My Company" /DAppId=<guid> /DPackageName=MyPlugin
;        /DBuildDir=<build>\MyPlugin_artefacts\Release [/DWithClap] /Odist packaging\windows\installer.iss

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
#ifndef AppName
  #define AppName "My Plugin"
#endif
#ifndef Publisher
  #define Publisher "My Company"
#endif
#ifndef AppId
  #error Pass /DAppId=<GUID> (INSTALLER_APP_ID in packaging/plugin.env)
#endif
#ifndef PackageName
  #define PackageName "MyPlugin"
#endif
#ifndef BuildDir
  #error Pass /DBuildDir=<the Release folder under <target>_artefacts>
#endif

[Setup]
; {{ is a literal brace: AppId becomes {GUID}. Never change the GUID once released.
AppId={{{#AppId}}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#Publisher}
; Only the uninstaller lives here; the plug-ins go to the standard folders below.
DefaultDirName={commonpf64}\{#Publisher}\{#AppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
OutputBaseFilename={#PackageName}-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#AppName} {#AppVersion}

#ifdef WithClap
[Types]
Name: "full"; Description: "VST3 and CLAP"
Name: "custom"; Description: "Choose formats"; Flags: iscustom

[Components]
Name: "vst3"; Description: "VST3 plug-in  (Common Files\VST3)"; Types: full custom
Name: "clap"; Description: "CLAP plug-in  (Common Files\CLAP)"; Types: full custom
#endif

[InstallDelete]
; Remove the previous bundle first so files dropped in a newer version don't linger.
Type: filesandordirs; Name: "{commoncf64}\VST3\{#AppName}.vst3"

[Files]
#ifdef WithClap
Source: "{#BuildDir}\VST3\{#AppName}.vst3\*"; DestDir: "{commoncf64}\VST3\{#AppName}.vst3"; \
    Components: vst3; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\CLAP\{#AppName}.clap"; DestDir: "{commoncf64}\CLAP"; Components: clap; Flags: ignoreversion
#else
Source: "{#BuildDir}\VST3\{#AppName}.vst3\*"; DestDir: "{commoncf64}\VST3\{#AppName}.vst3"; \
    Flags: ignoreversion recursesubdirs createallsubdirs
#endif

[UninstallDelete]
Type: filesandordirs; Name: "{commoncf64}\VST3\{#AppName}.vst3"

[Messages]
FinishedLabel={#AppName} is installed. Rescan plug-ins in your host if it doesn't show up.
