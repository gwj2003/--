@echo off
setlocal EnableExtensions

set "MODE=%~1"
set "NEO4J_WAIT_MAX=%~2"
if "%NEO4J_WAIT_MAX%"=="" set "NEO4J_WAIT_MAX=45"
set "QUIET_MISSING=0"
if /i "%MODE%"=="auto" set "QUIET_MISSING=1"
set "NEO4J_BAT="
set "NEEDS_ELEVATION=0"

call :resolve_neo4j_bat
if errorlevel 1 (
  if /i "%MODE%"=="auto" (
    echo [WARN] Neo4j launcher not found.
    echo [WARN] Continuing startup. QA graph features may be degraded.
    endlocal
    exit /b 0
  )
  exit /b 1
)

call :detect_elevation_need

call :is_port_listening 7687
if not errorlevel 1 (
  echo [OK] Neo4j is already running on port 7687.
  endlocal
  exit /b 0
)

if /i "%MODE%"=="auto" goto auto_mode

if "%NEEDS_ELEVATION%"=="1" (
  call :request_script_elevation
  endlocal
  exit /b 0
)

echo Starting Neo4j in console mode...
echo Using Neo4j launcher: %NEO4J_BAT%
call "%NEO4J_BAT%" console
set "NEO4J_EXIT=%errorlevel%"
if not "%NEO4J_EXIT%"=="0" pause

endlocal
exit /b %NEO4J_EXIT%

goto :eof

:auto_mode
echo [WARN] Neo4j is not listening on port 7687.
echo [*] Attempting to start Neo4j in a new window...
if "%NEEDS_ELEVATION%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%NEO4J_BAT%' -ArgumentList 'console' -Verb RunAs"
) else (
  start "Neo4j - BlueGuard" "%NEO4J_BAT%" console
)

echo [*] Waiting for Neo4j port 7687...
set /a NEO4J_WAIT_COUNT=0
:wait_neo4j
call :is_port_listening 7687
if not errorlevel 1 (
  echo [OK] Neo4j is now listening on port 7687.
  endlocal
  exit /b 0
)

set /a NEO4J_WAIT_COUNT+=1
if %NEO4J_WAIT_COUNT% GEQ %NEO4J_WAIT_MAX% goto neo4j_timeout
timeout /t 1 /nobreak >nul
goto wait_neo4j

:neo4j_timeout
echo [WARN] Neo4j did not become ready within %NEO4J_WAIT_MAX% seconds.
echo [WARN] Continuing startup. QA graph features may be degraded.
endlocal
exit /b 0

:resolve_neo4j_bat
if defined NEO4J_BIN goto check_neo4j_bin
goto check_neo4j_home

:check_neo4j_bin
if exist "%NEO4J_BIN%\neo4j.bat" (
  set "NEO4J_BAT=%NEO4J_BIN%\neo4j.bat"
  exit /b 0
)
if exist "%NEO4J_BIN%" (
  for %%F in ("%NEO4J_BIN%") do (
    if /i "%%~nxF"=="neo4j.bat" set "NEO4J_BAT=%%~fF"
  )
)
if defined NEO4J_BAT exit /b 0

goto check_neo4j_home

:check_neo4j_home
if defined NEO4J_HOME (
  if exist "%NEO4J_HOME%\bin\neo4j.bat" (
    set "NEO4J_BAT=%NEO4J_HOME%\bin\neo4j.bat"
    exit /b 0
  )
)

goto check_path

:check_path
for /f "delims=" %%I in ('where neo4j.bat 2^>nul') do (
  if not defined NEO4J_BAT (
    if /i not "%%~fI"=="%SystemRoot%\System32\neo4j.bat" set "NEO4J_BAT=%%~fI"
  )
)
if defined NEO4J_BAT exit /b 0

goto check_common

:check_common
if exist "%ProgramFiles%\Neo4j Community\bin\neo4j.bat" (
  set "NEO4J_BAT=%ProgramFiles%\Neo4j Community\bin\neo4j.bat"
  exit /b 0
)

for /f "delims=" %%D in ('dir /b /ad /o-n "%ProgramFiles%\neo4j-community-*" 2^>nul') do (
  if not defined NEO4J_BAT if exist "%ProgramFiles%\%%D\bin\neo4j.bat" (
    set "NEO4J_BAT=%ProgramFiles%\%%D\bin\neo4j.bat"
  )
)
if defined NEO4J_BAT exit /b 0

echo [ERROR] Cannot find Neo4j launcher (neo4j.bat).
echo [INFO] Please set NEO4J_HOME or add Neo4j bin directory to PATH.
if "%QUIET_MISSING%"=="0" pause
exit /b 1

:detect_elevation_need
set "NEEDS_ELEVATION=0"
echo %NEO4J_BAT% | find /i "%ProgramFiles%\" >nul
if errorlevel 1 exit /b 0

net session >nul 2>&1
if errorlevel 1 set "NEEDS_ELEVATION=1"
exit /b 0

:request_script_elevation
echo [INFO] Neo4j is under Program Files and needs Administrator permission.
echo [INFO] Requesting Administrator permission...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b 0

:is_port_listening
netstat -ano | findstr /r /c:":%~1 .*LISTENING" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0
