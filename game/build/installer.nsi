Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "nsDialogs.nsh"
Name "BLACKOUT: SECTOR 13"
OutFile "../../artifacts/BlackoutSector13-Setup-1.0.0.exe"
InstallDir "$LOCALAPPDATA\Programs\Blackout Sector 13"
InstallDirRegKey HKCU "Software\BlackoutSector13" "InstallPath"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 32
BrandingText "Created by Amir Saeid Dehghan"
VIProductVersion "1.0.0.0"
VIAddVersionKey /LANG=1033 "ProductName" "BLACKOUT: SECTOR 13"
VIAddVersionKey /LANG=1033 "FileDescription" "BLACKOUT: SECTOR 13 offline installer"
VIAddVersionKey /LANG=1033 "FileVersion" "1.0.0"
VIAddVersionKey /LANG=1033 "ProductVersion" "1.0.0"
VIAddVersionKey /LANG=1033 "CompanyName" "Amir Saeid Dehghan"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Created by Amir Saeid Dehghan"
!define MUI_ICON "../assets/ui/icon.ico"
!define MUI_UNICON "../assets/ui/icon.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "BLACKOUT: SECTOR 13"
!define MUI_WELCOMEPAGE_TEXT "Install the complete offline campaign for Windows x64.$\r$\n$\r$\nCreated by Amir Saeid Dehghan.$\r$\n$\r$\nVersion 1.0.0. This unsigned build has not been tested on Windows 11. See QA-Report.md for the exact test coverage."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\BlackoutSector13.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch BLACKOUT: SECTOR 13"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
Function .onInit
${IfNot} ${RunningX64}
 MessageBox MB_OK|MB_ICONSTOP "This game requires a 64-bit version of Windows."
 Abort
${EndIf}
SetShellVarContext current
FunctionEnd
Section "Game files (required)" SecGame
SectionIn RO
SetOutPath "$INSTDIR"
File "../../artifacts/release/BlackoutSector13.exe"
File "../../artifacts/release/BlackoutSector13.pck"
File "../../artifacts/release/Player-Guide-FA.html"
File "../../artifacts/release/QA-Report.md"
File "../../artifacts/release/THIRD-PARTY-NOTICES.txt"
CreateDirectory "$SMPROGRAMS\Blackout Sector 13"
CreateShortcut "$SMPROGRAMS\Blackout Sector 13\Blackout Sector 13.lnk" "$INSTDIR\BlackoutSector13.exe" "" "$INSTDIR\BlackoutSector13.exe" 0
CreateShortcut "$SMPROGRAMS\Blackout Sector 13\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
WriteUninstaller "$INSTDIR\Uninstall.exe"
WriteRegStr HKCU "Software\BlackoutSector13" "InstallPath" "$INSTDIR"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13" "DisplayName" "BLACKOUT: SECTOR 13"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13" "DisplayVersion" "1.0.0"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13" "Publisher" "Amir Saeid Dehghan"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13" "DisplayIcon" "$INSTDIR\BlackoutSector13.exe"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13" "UninstallString" '"$INSTDIR\Uninstall.exe"'
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13" "NoModify" 1
WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13" "NoRepair" 1
SectionEnd
Section /o "Desktop shortcut" SecDesktop
CreateShortcut "$DESKTOP\Blackout Sector 13.lnk" "$INSTDIR\BlackoutSector13.exe" "" "$INSTDIR\BlackoutSector13.exe" 0
SectionEnd
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!insertmacro MUI_DESCRIPTION_TEXT ${SecGame} "The executable, local game data, guide, QA report and license notices."
!insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Create an optional shortcut on your desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_END
Section "Uninstall"
SetShellVarContext current
Delete "$DESKTOP\Blackout Sector 13.lnk"
Delete "$SMPROGRAMS\Blackout Sector 13\Blackout Sector 13.lnk"
Delete "$SMPROGRAMS\Blackout Sector 13\Uninstall.lnk"
RMDir "$SMPROGRAMS\Blackout Sector 13"
Delete "$INSTDIR\BlackoutSector13.exe"
Delete "$INSTDIR\BlackoutSector13.pck"
Delete "$INSTDIR\Player-Guide-FA.html"
Delete "$INSTDIR\QA-Report.md"
Delete "$INSTDIR\THIRD-PARTY-NOTICES.txt"
Delete "$INSTDIR\Uninstall.exe"
RMDir "$INSTDIR"
DeleteRegKey HKCU "Software\BlackoutSector13"
DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BlackoutSector13"
; Per-user saved games and settings in %APPDATA%\BlackoutSector13 are preserved.
SectionEnd
