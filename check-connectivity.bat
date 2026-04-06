@echo off
setlocal
chcp 65001 >nul

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\check_connectivity.ps1"

echo.
if errorlevel 1 (
  echo [RESULT] Connectivity check has failures. Please review the checklist above.
) else (
  echo [RESULT] Connectivity check passed.
)

pause
