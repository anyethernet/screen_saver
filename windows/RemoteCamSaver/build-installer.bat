@echo off
setlocal
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo vswhere.exe not found
  exit /b 1
)
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
if not defined VSINSTALL (
  echo Visual C++ Build Tools not found
  exit /b 1
)
call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" || exit /b 1
cd /d "%~dp0"
call build.bat || exit /b 1
if not exist dist mkdir dist
rc /nologo /c 65001 /fo dist\installer.res installer.rc || exit /b 1
cl /nologo /std:c++17 /EHsc /O2 /MT /W3 /utf-8 /DUNICODE /D_UNICODE /Fodist\ /Fedist\RemoteCamSaver-Setup.exe installer.cpp dist\installer.res /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED /MANIFESTUAC:NO /MANIFESTINPUT:installer.manifest || exit /b 1
powershell -NoProfile -Command "if (Test-Path 'dist\RemoteCamSaver-Setup.exe') { try { Copy-Item -Force 'dist\RemoteCamSaver-Setup.exe' 'dist\원격카메라-설치.exe' } catch { Copy-Item -Force 'dist\RemoteCamSaver-Setup.exe' 'dist\RemoteCamSaver-Setup-new.exe'; Copy-Item -Force 'dist\RemoteCamSaver-Setup-new.exe' 'dist\원격카메라-설치.exe' } } else { exit 1 }" || exit /b 1
echo Built %~dp0dist\RemoteCamSaver-Setup.exe and 원격카메라-설치.exe
