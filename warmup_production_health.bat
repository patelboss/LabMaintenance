@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Cooldown (Fixed & Stable)

:: ==================================================
:: PATHS (SELF-CONTAINED, SAFE)
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "PIDFILE=%BASEDIR%\cpu_pids.txt"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1

echo.
echo =============================================
echo   Lab Maintenance Script Starting
echo =============================================

:: ==================================================
:: LOG FILE INIT (INLINE, SAFE)
:: ==================================================
echo ===== SCRIPT START %date% %time% ===== >> "%LOGFILE%"
echo [INFO] Script launched

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [STEP] Checking administrator rights
echo [STEP] Checking administrator rights >> "%LOGFILE%"
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Administrator rights required
    echo [ERROR] Administrator rights required >> "%LOGFILE%"
    pause
    exit /b 1
)
echo [OK] Admin confirmed
echo [OK] Admin confirmed >> "%LOGFILE%"

:: ==================================================
:: CONFIGURATION
:: ==================================================
set WARMUP_SECONDS=20
set COOLDOWN_SECONDS=20
set SHUTDOWN_WARNING_SECONDS=20

echo [CONFIG] Warmup=%WARMUP_SECONDS% Cooldown=%COOLDOWN_SECONDS% Shutdown=%SHUTDOWN_WARNING_SECONDS%
echo [CONFIG] Warmup=%WARMUP_SECONDS% Cooldown=%COOLDOWN_SECONDS% Shutdown=%SHUTDOWN_WARNING_SECONDS% >> "%LOGFILE%"

:: ==================================================
:: PC ID
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [SETUP] Enter PC ID:
    set /p PCID=
    echo %PCID% > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
echo [INFO] PC ID=%PCID%
echo [INFO] PC ID=%PCID% >> "%LOGFILE%"

:: ==================================================
:: CPU LOAD CALCULATION
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

echo [INFO] CPU Load Workers=%LOAD%
echo [INFO] CPU Load Workers=%LOAD% >> "%LOGFILE%"

:: ==================================================
:: START CPU LOAD (NATIVE STYLE)
:: ==================================================
if exist "%PIDFILE%" del "%PIDFILE%"

echo [STEP] Starting CPU load
echo [STEP] Starting CPU load >> "%LOGFILE%"

for /L %%A in (1,1,%LOAD%) do (
    start "Maint_Worker" /min cmd /c "for /L %%i in () do rem"
)

echo [OK] CPU load running
echo [OK] CPU load running >> "%LOGFILE%"

:: ==================================================
:: WARM-UP LOOP (VISIBLE)
:: ==================================================
set REMAIN=%WARMUP_SECONDS%
color 0B

:WARMUP
cls
echo =============================================
echo   WARM-UP IN PROGRESS : %PCID%
echo   Remaining Time     : %REMAIN% sec
echo =============================================

if %REMAIN% LEQ 0 goto END_WARMUP
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto WARMUP

:END_WARMUP
color 07
echo [STEP] Warm-up completed
echo [STEP] Warm-up completed >> "%LOGFILE%"

:: ==================================================
:: COOL-DOWN
:: ==================================================
echo [STEP] Cool-down started (%COOLDOWN_SECONDS% sec)
echo [STEP] Cool-down started (%COOLDOWN_SECONDS% sec) >> "%LOGFILE%"
timeout /t %COOLDOWN_SECONDS% /nobreak >nul
echo [STEP] Cool-down completed
echo [STEP] Cool-down completed >> "%LOGFILE%"

:: ==================================================
:: SHUTDOWN
:: ==================================================
echo [STEP] Shutdown scheduled
echo [STEP] Shutdown scheduled >> "%LOGFILE%"
echo ===== SCRIPT END %date% %time% ===== >> "%LOGFILE%"

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Use shutdown /a to cancel."

echo.
echo System will shut down shortly.
echo This window will remain open.
pause >nul
