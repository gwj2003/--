@echo off
setlocal EnableExtensions

cd /d "%~dp0..\backend"
set "VENV_NAME=blueguard"
set "VENV_DIR=%CD%\%VENV_NAME%"
set "VENV_PY_VENV=%VENV_DIR%\Scripts\python.exe"
set "VENV_PY_CONDA=%VENV_DIR%\python.exe"
set "VENV_PY=%VENV_PY_VENV%"
set "ALLOWED_PY_1=3.12"
set "ALLOWED_PY_2="
set "ALLOWED_PY_3="
set "SELECTED_PY="
set "CURR_PY_VER="
set "SYS_PY_VER="
set "CREATE_MODE=venv"
set "CONDA_CMD="
set "REQ_HASH_FILE=%VENV_DIR%\.requirements.sha256"
set "REQ_HASH="
set "LAST_REQ_HASH="

echo [Backend] Working directory: %CD%
echo [Backend] Virtual env directory: %VENV_DIR%

call :ensure_venv
if errorlevel 1 (
  pause
  exit /b 1
)

call :resolve_env_python

if not exist "%VENV_PY%" (
  echo [Backend][ERROR] Virtual environment python executable was not found.
  echo [Backend] Tried: %VENV_PY_VENV%
  echo [Backend] Tried: %VENV_PY_CONDA%
  pause
  exit /b 1
)

set "PATH=%VENV_DIR%\Scripts;%PATH%"
set "PIP_NO_WARN_SCRIPT_LOCATION=1"

call :calc_requirements_hash
if errorlevel 1 (
  echo [Backend][ERROR] Failed to calculate requirements hash.
  pause
  exit /b 1
)

if exist "%REQ_HASH_FILE%" (
  set /p LAST_REQ_HASH=<"%REQ_HASH_FILE%"
)

if /i "%REQ_HASH%"=="%LAST_REQ_HASH%" (
  echo [Backend] requirements.txt unchanged. Skipping dependency install.
) else (
  echo [Backend] requirements.txt changed or first run. Installing dependencies...
  "%VENV_PY%" -m pip install --upgrade pip --no-warn-script-location
  if errorlevel 1 (
    echo [Backend][ERROR] Failed to upgrade pip in virtual environment.
    pause
    exit /b 1
  )

  "%VENV_PY%" -m pip install -r requirements.txt --no-warn-script-location
  if errorlevel 1 (
    echo [Backend][ERROR] Dependency installation failed.
    echo [Backend] Ensure Python 3.12 is available for this project.
    pause
    exit /b 1
  )

  >"%REQ_HASH_FILE%" echo %REQ_HASH%
)

echo [Backend] Starting FastAPI on http://localhost:8000 ...
"%VENV_PY%" -m uvicorn main:app --reload --port 8000 --host 0.0.0.0

echo [Backend] Server stopped.
pause
exit /b 0

:ensure_venv
call :resolve_env_python
if exist "%VENV_PY%" (
  set "CURR_PY_VER="
  set "CURR_PY_FULL="
  for /f "tokens=2" %%v in ('"%VENV_PY%" --version') do set "CURR_PY_FULL=%%v"
  if defined CURR_PY_FULL (
    for /f "tokens=1,2 delims=." %%a in ("%CURR_PY_FULL%") do set "CURR_PY_VER=%%a.%%b"
  )

  if not defined CURR_PY_VER (
    echo [Backend][ERROR] Failed to detect Python version from existing environment.
    echo [Backend] Python path: %VENV_PY%
    exit /b 1
  )

  call :is_allowed_python "%CURR_PY_VER%"
  if errorlevel 1 (
    echo [Backend] Existing virtual environment uses Python %CURR_PY_VER% which is not supported by current pinned dependencies.
    echo [Backend] Recreating virtual environment blueguard with a compatible Python version...
    rmdir /s /q "%VENV_DIR%"
    if exist "%VENV_DIR%" (
      echo [Backend][ERROR] Failed to remove old virtual environment at %VENV_DIR%.
      exit /b 1
    )
  ) else (
    echo [Backend] Reusing existing virtual environment: blueguard ^(Python %CURR_PY_VER%^)
    exit /b 0
  )
)

call :pick_python_for_venv
if not defined SELECTED_PY (
  echo [Backend][ERROR] No compatible Python found.
  echo [Backend] Install Python 3.12, or ensure conda is installed and discoverable.
  exit /b 1
)

echo [Backend] Creating virtual environment blueguard using %SELECTED_PY% ...
if /i "%CREATE_MODE%"=="conda" (
  %CONDA_CMD% create -p "%VENV_DIR%" python=%ALLOWED_PY_1% pip -y
  if errorlevel 1 (
    echo [Backend][ERROR] Failed to create blueguard via conda.
    exit /b 1
  )
) else (
  %SELECTED_PY% -m venv "%VENV_DIR%"
  if errorlevel 1 (
    echo [Backend][ERROR] Failed to create virtual environment blueguard.
    exit /b 1
  )
)

exit /b 0

:pick_python_for_venv
where conda >nul 2>&1
if not errorlevel 1 (
  set "CREATE_MODE=conda"
  set "CONDA_CMD=conda"
  set "SELECTED_PY=conda -p %VENV_DIR% ^(python %ALLOWED_PY_1%^)"
  exit /b 0
)

if exist "%USERPROFILE%\anaconda3\Scripts\conda.exe" (
  set "CREATE_MODE=conda"
  set "CONDA_CMD=\"%USERPROFILE%\anaconda3\Scripts\conda.exe\""
  set "SELECTED_PY=conda.exe -p %VENV_DIR% ^(python %ALLOWED_PY_1%^)"
  exit /b 0
)

where py >nul 2>&1
if not errorlevel 1 (
  for %%p in (%ALLOWED_PY_1%) do (
    py -%%p -c "import sys" >nul 2>&1
    if not errorlevel 1 (
      set "SELECTED_PY=py -%%p"
      exit /b 0
    )
  )
)

for /f "tokens=2" %%v in ('python --version 2^>nul') do set "SYS_PY_FULL=%%v"
if defined SYS_PY_FULL (
  for /f "tokens=1,2 delims=." %%a in ("%SYS_PY_FULL%") do set "SYS_PY_VER=%%a.%%b"
)

if defined SYS_PY_VER (
  call :is_allowed_python "%SYS_PY_VER%"
  if not errorlevel 1 (
    set "SELECTED_PY=python"
    exit /b 0
  )
)

exit /b 0

:resolve_env_python
if exist "%VENV_PY_VENV%" (
  set "VENV_PY=%VENV_PY_VENV%"
  exit /b 0
)

if exist "%VENV_PY_CONDA%" (
  set "VENV_PY=%VENV_PY_CONDA%"
  exit /b 0
)

set "VENV_PY=%VENV_PY_VENV%"
exit /b 0

:calc_requirements_hash
set "REQ_HASH="
for /f "skip=1 tokens=1" %%h in ('certutil -hashfile "requirements.txt" SHA256') do (
  set "REQ_HASH=%%h"
  goto :calc_requirements_hash_done
)

:calc_requirements_hash_done
if not defined REQ_HASH exit /b 1
exit /b 0

:is_allowed_python
if /i "%~1"=="%ALLOWED_PY_1%" exit /b 0
if /i "%~1"=="%ALLOWED_PY_2%" exit /b 0
if /i "%~1"=="%ALLOWED_PY_3%" exit /b 0
exit /b 1
