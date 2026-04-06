@echo off
setlocal

cd /d "%~dp0..\backend"
set "USE_CONDA=0"
set "CONDA_ENV=blueguard"

rem Prefer using `conda run -n blueguard` if conda is available
where conda >nul 2>&1
if not errorlevel 1 (
  set "USE_CONDA=1"
)

if "%USE_CONDA%"=="1" (
  echo [Backend] Using conda environment: %CONDA_ENV%
  echo [Backend] Installing dependencies (conda run)...
  rem Ensure the conda environment exists; create from environment.yml if missing
  conda env list | findstr /C:"%CONDA_ENV%" >nul 2>&1
  if errorlevel 1 (
    echo [Backend] Conda env %CONDA_ENV% not found. Creating from environment.yml...
    conda env create -f "%~dp0..\environment.yml"
    if errorlevel 1 (
      echo [Backend][ERROR] failed to create conda env %CONDA_ENV%.
      echo [Backend] Falling back to local python.
      set "USE_CONDA=0"
    )
  )
  if "%USE_CONDA%"=="1" (
    conda run -n %CONDA_ENV% --no-capture-output python -m pip install -r requirements.txt
    if errorlevel 1 (
      echo [Backend][ERROR] pip install failed inside conda environment %CONDA_ENV%.
      echo [Backend] Falling back to local python.
      set "USE_CONDA=0"
    )
  )
)

if "%USE_CONDA%"=="0" (
  set "PYTHON_CMD=python"

  echo [Backend] Python executable: %PYTHON_CMD%
  echo [Backend] Working directory: %CD%
  echo [Backend] Installing dependencies (system python)...
  "%PYTHON_CMD%" -m pip install -r requirements.txt
  if errorlevel 1 (
    echo [Backend][ERROR] pip install failed.
    echo [Backend] Please create the Conda environment 'blueguard' or ensure system python can install dependencies.
    pause
    exit /b 1
  )
)

echo [Backend] Starting FastAPI on http://localhost:8000 ...
if "%USE_CONDA%"=="1" (
  conda run -n %CONDA_ENV% --no-capture-output python -m uvicorn main:app --reload --port 8000 --host 0.0.0.0
) else (
  "%PYTHON_CMD%" -m uvicorn main:app --reload --port 8000 --host 0.0.0.0
)

echo [Backend] Server stopped.
pause
