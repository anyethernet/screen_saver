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
if not exist build mkdir build
if not exist build\testobj mkdir build\testobj
rc /nologo /c 65001 /fo build\app.res app.rc || exit /b 1
cl /nologo /std:c++17 /EHsc /O2 /MT /W3 /utf-8 /DUNICODE /D_UNICODE /Fobuild\ /Febuild\RemoteCamSaver.scr main.cpp settings.cpp stream.cpp tailscale.cpp build\app.res /link /SUBSYSTEM:WINDOWS || exit /b 1
cl /nologo /std:c++17 /EHsc /O2 /MT /W3 /utf-8 /DUNICODE /D_UNICODE /Fobuild\testobj\ /Febuild\mjpeg_selftest.exe selftest.cpp stream.cpp tailscale.cpp /link /SUBSYSTEM:CONSOLE || exit /b 1
echo Built %~dp0build\RemoteCamSaver.scr
