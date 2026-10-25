@echo off
set "SCR=%~dp0build\RemoteCamSaver.scr"
if not exist "%SCR%" (
  echo 먼저 build.bat 로 화면 보호기를 빌드하세요.
  exit /b 1
)
powershell -NoProfile -Command "$p = New-Object System.Diagnostics.ProcessStartInfo; $p.FileName = $env:SCR; $p.Arguments = '/c'; $p.UseShellExecute = $false; [void][Diagnostics.Process]::Start($p)"
