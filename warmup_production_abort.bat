@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production (STOP.txt Feature Test)

:: ==================================================
:: BASE PATHS
:: ==================================================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health
set MONTHLYDIR=%HEALTHDIR%\Monthly
set PIDFILE=%BASEDIR%\cpu_pids.txt
set STOPFILE=%BASEDIR%\STOP.txt

if not exist "%BASEDIR%" mkdir "%BASEDIR%"
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%"
if exist "%PIDFILE%" del "%PIDFILE%"

echo.>>"%LOGFILE%"
echo ===== SCRIPT START %date% %time% =====>>"%LOGFILE%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [STEP] Checking admin rights>>"%LOGFILE%"
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Not running as administrator>>"%LOGFILE%"
    pause
    exit /b 1
)
echo [OK] Admin confirmed>>"%LOGFILE%"

:: ==================================================
:: CONFIGURATION (SECONDS)
:: ==================================================
set WARMUP_SECONDS=1800
set SHUTDOWN_WARNING_SECONDS=120

echo [CONFIG] Warmup=%WARMUP_SECONDS% sec Shutdown=%SHUTDOWN_WARNING_SECONDS% sec>>"%LOGFILE%"

:: ==================================================
:: PC ID
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [ERROR] pc_id.txt missing>>"%LOGFILE%"
    exit /b 1
)
set /p PCID=<"%PCIDFILE%"
echo [INFO] PC ID=%PCID%>>"%LOGFILE%"

:: ==================================================
:: CPU LOAD CALCULATION (~50%)
:: ==================================================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1
echo [INFO] CPU cores=%CORES% LoadWorkers=%LOAD%>>"%LOGFILE%"

:: ==================================================
:: START CPU LOAD (PID-TRACKED)
:: ==================================================
echo [STEP] Starting CPU load>>"%LOGFILE%"

for /L %%A in (1,1,%LOAD%) do (
    powershell -NoProfile -Command ^
    "$p = Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile -Command while($true){Start-Sleep -Milliseconds 10}'; ^
     Add-Content '%PIDFILE%' $p.Id"
)

echo [OK] CPU load running>>"%LOGFILE%"

:: ==================================================
:: WARM-UP LOOP (STOP.txt CHECK)
:: ==================================================
set REMAIN=%WARMUP_SECONDS%
color 0B
echo [STEP] Entering warmup loop>>"%LOGFILE%"
echo [FEATURE: STOP.txt] Create STOP.txt to abort>>"%LOGFILE%"

:COUNTDOWN
if exist "%STOPFILE%" goto ABORT
if !REMAIN! LEQ 0 goto FINISH

powershell -NoProfile -Command "Start-Sleep -Seconds 1"
set /a REMAIN-=1
goto COUNTDOWN

:: ==================================================
:: ABORT HANDLER (STOP.txt)
:: ==================================================
:ABORT
color 07
echo [FEATURE: STOP.txt] STOP file detected>>"%LOGFILE%"
echo [STEP] Stopping CPU load due to STOP.txt>>"%LOGFILE%"

if exist "%PIDFILE%" (
    for /f %%P in (%PIDFILE%) do (
        powershell -NoProfile -Command "Stop-Process -Id %%P -Force -ErrorAction SilentlyContinue"
    )
    del "%PIDFILE%"
)

echo [INFO] Script aborted via STOP.txt>>"%LOGFILE%"
echo ===== SCRIPT END (ABORTED) %date% %time% =====>>"%LOGFILE%"
exit /b 0

:: ==================================================
:: NORMAL FINISH
:: ==================================================
:FINISH
color 07
echo [STEP] Warmup completed>>"%LOGFILE%"

:: ==================================================
:: STOP CPU LOAD
:: ==================================================
echo [STEP] Stopping CPU load>>"%LOGFILE%"

if exist "%PIDFILE%" (
    for /f %%P in (%PIDFILE%) do (
        powershell -NoProfile -Command "Stop-Process -Id %%P -Force -ErrorAction SilentlyContinue"
    )
    del "%PIDFILE%"
)

echo [OK] CPU load stopped>>"%LOGFILE%"

:: ==================================================
:: SHUTDOWN (UNCHANGED)
:: ==================================================
echo [STEP] Shutdown timer started>>"%LOGFILE%"
shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."

echo ===== SCRIPT END %date% %time% =====>>"%LOGFILE%"
exit /b 0
