@echo off
setlocal EnableExtensions
chcp 65001 >nul

cd /d "%~dp0.."

set "ROOT_DIR=%CD%\"
set "BACKEND_RUNNER=%ROOT_DIR%scripts\run_backend.bat"
set "FRONTEND_RUNNER=%ROOT_DIR%scripts\run_frontend.bat"
set "NEO4J_STARTER=%ROOT_DIR%scripts\start-neo4j.bat"
set "FRONTEND_WAIT_MAX=120"
set "NEO4J_WAIT_MAX=45"

echo.
echo ====================================================
echo   BlueGuard Platform - Startup
echo ====================================================
echo.

REM Check dependencies
echo [*] Checking dependencies...
if not exist "%BACKEND_RUNNER%" (
    echo [ERROR] Missing file: %BACKEND_RUNNER%
    goto :fail
)
echo [OK] Backend runner found.

if not exist "%FRONTEND_RUNNER%" (
    echo [ERROR] Missing file: %FRONTEND_RUNNER%
    goto :fail
)
echo [OK] Frontend runner found.

python --version >nul 2>&1
if errorlevel 1 (
    if not exist "%ROOT_DIR%backend\env\python.exe" (
        echo [ERROR] Python not found in PATH and local env is missing.
        echo         Expected fallback: %ROOT_DIR%backend\env\python.exe
        goto :fail
    )
)
echo [OK] Python check passed. npm will be checked in frontend window.

echo [OK] Skipping npm pre-check in launcher (frontend window will validate npm).
echo [OK] Root: %ROOT_DIR%
echo.

call :ensure_neo4j_running
echo.

REM Start backend
echo [*] Starting backend on port 8000...
start "Backend - BlueGuard" "%BACKEND_RUNNER%"
if errorlevel 1 (
    echo [ERROR] Failed to launch backend window.
    goto :fail
)

timeout /t 3 /nobreak > nul

REM Start frontend
echo [*] Starting frontend on port 5173...
start "Frontend - BlueGuard" "%FRONTEND_RUNNER%"
if errorlevel 1 (
    echo [ERROR] Failed to launch frontend window.
    goto :fail
)

timeout /t 5 /nobreak > nul

REM First run may spend extra time in npm install.
if not exist "%ROOT_DIR%frontend\node_modules\" (
    set "FRONTEND_WAIT_MAX=300"
    echo [INFO] First frontend setup detected. Wait timeout set to 300 seconds.
)

REM Clear screen and display info
cls
echo.
echo ====================================================
echo   Services Started
echo ====================================================
echo.
echo Frontend: http://localhost:5173
echo Backend : http://localhost:8000
echo API Docs: http://localhost:8000/docs
echo.
echo Notes:
echo   - Check the two newly opened terminal windows for logs.
echo   - Press Ctrl+C inside each window to stop its service.
echo   - Closing those windows will stop the services.
echo.
echo ====================================================
echo.
echo [*] Waiting for frontend port 5173...
set /a WAIT_COUNT=0
:wait_frontend
netstat -ano | findstr ":5173" | findstr "LISTENING" >nul
if not errorlevel 1 goto frontend_ready
set /a WAIT_COUNT+=1
if %WAIT_COUNT% GEQ %FRONTEND_WAIT_MAX% goto frontend_timeout
timeout /t 1 /nobreak >nul
goto wait_frontend

:frontend_ready
echo [OK] Frontend is listening on port 5173.
goto open_browser

:frontend_timeout
echo [WARN] Frontend did not listen on port 5173 within %FRONTEND_WAIT_MAX% seconds.
echo [WARN] This is common on first run while npm install is still running.
echo [WARN] Browser will still be opened. Check frontend window logs.

:open_browser

REM Open browser
echo [*] Opening http://localhost:5173
start "" "http://localhost:5173"

echo.
echo Launcher finished. You can close this window.
pause
exit /b 0

:ensure_neo4j_running
if not exist "%NEO4J_STARTER%" (
    echo [WARN] Neo4j starter not found: %NEO4J_STARTER%
    echo [WARN] Continuing startup. QA graph features may be degraded.
    exit /b 0
)

call "%NEO4J_STARTER%" auto "%NEO4J_WAIT_MAX%"
exit /b 0

:fail
echo.
echo Launcher stopped due to missing dependencies or invalid environment.
pause
exit /b 1
