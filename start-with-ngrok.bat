@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo.
echo ====================================================
echo   BlueGuard - ngrok 启动工具
echo ====================================================
echo.

cd /d "%~dp0"
set "ROOT_DIR=%~dp0"
set "BACKEND_RUNNER=%ROOT_DIR%scripts\run_backend.bat"
set "FRONTEND_RUNNER=%ROOT_DIR%scripts\run_frontend.bat"
set "NEO4J_STARTER=%ROOT_DIR%scripts\start-neo4j.bat"
set "NEO4J_WAIT_MAX=45"
set "FRONTEND_WAIT_MAX=180"

if not exist "%BACKEND_RUNNER%" (
  echo [ERROR] Missing file: %BACKEND_RUNNER%
  pause
  exit /b 1
)

if not exist "%FRONTEND_RUNNER%" (
  echo [ERROR] Missing file: %FRONTEND_RUNNER%
  pause
  exit /b 1
)

REM 检查 ngrok 是否已安装
where ngrok >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] ngrok 未安装或未添加到 PATH
    echo.
    echo 请按以下步骤安装：
    echo   1. 访问 https://ngrok.com/download 下载 ngrok
    echo   2. 将 ngrok.exe 添加到你的 PATH
    echo   3. 或在终端中手动运行：ngrok http 5173
    echo.
    pause
    exit /b 1
)

echo [OK] ngrok 已安装

echo.
echo ====================================================
echo   启动步骤
echo ====================================================
echo.
echo 将使用 3-4 个终端窗口启动以下服务：
echo   1. 终端 1：后端服务 ^(FastAPI, 端口 8000^)
echo   2. 终端 2：前端服务 ^(Vite, 端口 5173^)
echo   3. 终端 3：ngrok 隧道 ^(将端口 5173 暴露到公网^)
echo   4. Neo4j 未运行时会自动尝试拉起
echo.

pause

call :ensure_neo4j_running
echo.

echo [*] 启动终端 1：后端服务...
start "BlueGuard Backend" "%BACKEND_RUNNER%"

timeout /t 3 /nobreak

echo [*] 启动终端 2：前端服务...
start "BlueGuard Frontend" "%FRONTEND_RUNNER%"

echo [*] 等待前端端口 5173 就绪（最长 %FRONTEND_WAIT_MAX% 秒）...
set /a FRONTEND_WAIT_COUNT=0
:wait_frontend
netstat -ano | findstr ":5173" | findstr "LISTENING" >nul
if not errorlevel 1 goto frontend_ready
set /a FRONTEND_WAIT_COUNT+=1
if %FRONTEND_WAIT_COUNT% GEQ %FRONTEND_WAIT_MAX% goto frontend_timeout
timeout /t 1 /nobreak >nul
goto wait_frontend

:frontend_ready
echo [OK] 前端服务已监听 5173，启动 ngrok。
goto start_ngrok

:frontend_timeout
echo [WARN] 前端端口在等待时间内未就绪，仍将启动 ngrok。
echo [WARN] 首次安装依赖时可能需要更久，可稍后刷新 ngrok 页面。

:start_ngrok
echo [*] 启动终端 3：ngrok 隧道...
start "BlueGuard ngrok" cmd /k "ngrok http 5173"

timeout /t 2 /nobreak

echo.
echo ====================================================
echo   服务启动完成
echo ====================================================
echo.
echo ngrok URL will appear in the ngrok window.
echo Example: https://xxxx-xxxx-xxxx.ngrok-free.dev
echo.
echo Local app: http://localhost:5173
echo.
echo Troubleshooting:
echo   - If ngrok reports an auth error, run: ngrok authtoken YOUR_TOKEN
echo   - If the backend fails, check whether Neo4j is running
echo   - If the frontend fails, make sure npm install has completed
echo.

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
