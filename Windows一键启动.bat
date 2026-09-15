@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\OneClick.ps1"
if errorlevel 1 (
  echo Launcher failed. See the message above.
  pause
  exit /b 1
)
exit /b 0