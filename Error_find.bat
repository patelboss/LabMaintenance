@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Stable Execution Mode

echo ==================================================
echo   LAB MAINTENANCE SCRIPT INITIALIZING
echo ==================================================
echo If you can read this, the script has started.
echo.

:: ==================================================
:: BASE LOCATION (SELF-CONTAINED)
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "PIDFILE=%BASEDIR%\cpu_pids.txt"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1

:: ==================================================
:: LOG FILE TEST
:: ==================================================
echo [INFO] Checking log write capability...
echo Log test > "%BASEDIR%\.__log_test.tmp" 2>nul

if exist "%BASEDIR%\.__log_test.tmp" (
    del "%BASEDIR%\.__log_test.tmp"
    echo [INFO] Log directory is writable.
    echo ===== SCRIPT START %date% %time% ===== > "%LOGFILE%"
    set LOGMODE=FILE
) else (
    echo [WARN] Cannot write log file. Running in screen-only mode.
    set LOGMODE=SCREEN
)

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [STEP] Verifying administrator rights
if "%LOGMODE%"=="FILE" echo [STEP] Verifying administrator rights >> "%LOGFILE%"

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Administrator rights are required.
    if "%LOGMODE%"=="FILE" echo [ERROR] Administrator rights missing >> "%LOGFILE%"
    pause
    goto HOLD
)

echo [OK] Administrator rights confirmed
if "%LOGMODE%"=="FILE" echo [OK] Administrator rights confirmed >> "%LOGFILE%"

:: ==================================================
:: CONFIGURATION
:: ==================================================
set WARMUP_SECONDS=20
set SHUTDOWN_WARNING_SECONDS=20

echo [INFO] Warm-up duration  : %WARMUP_SECONDS% seconds
echo [INFO] Shutdown delay    : %SHUTDOWN_WARNING_SECONDS% seconds
if "%LOGMODE%"=="FILE" (
    echo [INFO] Warm-up duration  : %WARMUP_SECONDS% seconds >> "%LOGFILE%"
    echo [INFO] Shutdown delay    : %SHUTDOWN_WARNING_SECONDS% seconds >> "%LOGFILE%"
)

:: ==================================================
:: PC IDENTIFICATION
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [SETUP] No PC ID found. Please enter an ID:
    set /p PCID=
    echo %PCID% > "%PCIDFILE%"
)

set /p PCID=<"%PCIDFILE%"
echo [INFO] PC ID in use: %PCID%
if "%LOGMODE%"=="FILE" echo [INFO] PC ID in use: %PCID% >> "%LOGFILE%"

:: ==================================================
:: CPU LOAD CALCULATION
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

echo [INFO] CPU cores detected : %NUMBER_OF_PROCESSORS%
echo [INFO] Load workers used  : %LOAD%
if "%LOGMODE%"=="FILE" (
    echo [INFO] CPU cores detected : %NUMBER_OF_PROCESSORS% >> "%LOGFILE%"
    echo [INFO] Load workers used  : %LOAD% >> "%LOGFILE%"
)

:: ==================================================
:: START CPU LOAD (NATIVE, SAFE)
:: ==================================================
if exist "%PIDFILE%" del "%PIDFILE%"

echo [STEP] Starting CPU warm-up load
if "%LOGMODE%"=="FILE" echo [STEP] Starting CPU warm-up load >> "%LOGFILE%"

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_CPU_LOAD" /min cmd /c "for /L %%i in () do rem"
)

echo [OK] CPU load is now active
if "%LOGMODE%"=="FILE" echo [OK] CPU load is now active >> "%LOGFILE%"

:: ==================================================
:: WARM-UP TIMER
:: ==================================================
set REMAIN=%WARMUP_SECONDS%
color 0B

:WARMUP_LOOP
cls
echo ==================================================
echo   SYSTEM WARM-UP IN PROGRESS
echo   PC ID      : %PCID%
echo   Time Left  : %REMAIN% seconds
echo ==================================================

if "%LOGMODE%"=="FILE" echo [DEBUG] Warm-up remaining: %REMAIN% sec >> "%LOGFILE%"

if %REMAIN% LEQ 0 goto WARMUP_DONE
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto WARMUP_LOOP

:WARMUP_DONE
color 07
echo [OK] Warm-up phase completed
if "%LOGMODE%"=="FILE" echo [OK] Warm-up phase completed >> "%LOGFILE%"

:: ==================================================
:: SHUTDOWN SEQUENCE
:: ==================================================
echo [STEP] Scheduling system shutdown
if "%LOGMODE%"=="FILE" (
    echo [STEP] Scheduling system shutdown >> "%LOGFILE%"
    echo ===== SCRIPT END %date% %time% ===== >> "%LOGFILE%"
)

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Use shutdown /a to cancel."

:: ==================================================
:: HOLD WINDOW OPEN
:: ==================================================
:HOLD
echo.
echo ==================================================
echo   Script is still running.
echo   System will shut down automatically.
echo ==================================================
pause >nul
goto HOLD
