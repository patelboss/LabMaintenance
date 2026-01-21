@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Standalone Production

:: ==================================================
:: PATHS & IDENTITY (Self-Contained)
:: ==================================================
:: %~dp0 makes the script look in its own folder, no matter where it's moved
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"

if not exist "%BASEDIR%" mkdir "%BASEDIR%"

:: If pc_id.txt doesn't exist, ask you once. Otherwise, read it.
if not exist "%PCIDFILE%" (
    echo [SETUP] No PC ID found.
    set /p "USER_PCID=Enter the ID for this PC: "
    echo !USER_PCID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"

echo ===== START %date% %time% [%PCID%] ===== >> "%LOGFILE%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Not running as administrator.
    pause
    exit /b 1
)

:: ==================================================
:: CONFIGURATION
:: ==================================================
set "WARMUP_SECONDS=20"
set "SHUTDOWN_SECONDS=20"
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

echo [INFO] CPU Load Workers: %LOAD% >> "%LOGFILE%"

:: ==================================================
:: START CPU LOAD (Independent Method)
:: ==================================================
echo [STEP] Starting CPU load...
:: We use a unique Window Title so we can kill it later without tracking PIDs
for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_STRESS_PROCESS" /min powershell -NoProfile -Command "while($true){}"
)

:: ==================================================
:: WARM-UP LOOP (Native Performance)
:: ==================================================
set "REMAIN=%WARMUP_SECONDS%"
color 0B
:COUNTDOWN
cls
echo ==================================================
echo   STABILIZING SYSTEM: %PCID%
echo   Remaining Warm-up: !REMAIN! seconds
echo ==================================================
if !REMAIN! LEQ 0 goto FINISH
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto COUNTDOWN

:: ==================================================
:: CLEANUP & SHUTDOWN
:: ==================================================
:FINISH
color 07
echo [STEP] Stopping CPU load...
:: Kills only the processes we tagged with the unique title
taskkill /FI "WINDOWTITLE eq MAINT_STRESS_PROCESS*" /F /IM powershell.exe >nul 2>&1

echo [STEP] Maintenance complete. Triggering Shutdown. >> "%LOGFILE%"
echo ===== END %date% %time% ===== >> "%LOGFILE%"

shutdown /s /t %SHUTDOWN_SECONDS% /c "Maintenance on %PCID% complete. Use 'shutdown /a' to cancel."
exit /b 0

