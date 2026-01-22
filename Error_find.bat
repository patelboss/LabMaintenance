@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production (Verbose Debug Mode)

:: ==================================================
:: BASE PATHS
:: ==================================================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health
set MONTHLYDIR=%HEALTHDIR%\Monthly
set PIDFILE=%BASEDIR%\cpu_pids.txt
set LOG_OK=1

echo.
echo =============================================
echo   Lab Maintenance Script Starting
echo =============================================

:: ==================================================
:: CREATE DIRECTORIES
:: ==================================================
if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1

:: ==================================================
:: LOG PERMISSION CHECK
:: ==================================================
echo [INFO] Checking log file permissions...

echo test > "%BASEDIR%\.__log_test.tmp" 2>nul
if not exist "%BASEDIR%\.__log_test.tmp" (
    echo [ERROR] Cannot write to %BASEDIR%
    echo [ERROR] Logging will be screen-only
    set LOG_OK=0
) else (
    del "%BASEDIR%\.__log_test.tmp"
    echo [INFO] Log directory writable
)

:: ==================================================
:: INITIALIZE LOG FILE (IF POSSIBLE)
:: ==================================================
if %LOG_OK%==1 (
    >"%LOGFILE%" echo ===== SCRIPT START %date% %time% =====
)

:: ==================================================
:: LOG SUBROUTINE (SAFE)
:: ==================================================
:LOG
set "LEVEL=%~1"
set "MSG=%~2"
echo [%LEVEL%] %MSG%
if %LOG_OK%==1 echo [%LEVEL%] %MSG%>>"%LOGFILE%"
exit /b

:: ==================================================
:: ADMIN CHECK
:: ==================================================
call :LOG STEP "Checking administrator privileges"
net session >nul 2>&1
if %errorlevel% neq 0 (
    call :LOG ERROR "Administrator rights NOT present"
    pause
    goto HOLD
)
call :LOG OK "Administrator rights confirmed"

:: ==================================================
:: CONFIGURATION
:: ==================================================
set WARMUP_SECONDS=20
set SHUTDOWN_WARNING_SECONDS=20

call :LOG INFO "WARMUP_SECONDS=%WARMUP_SECONDS%"
call :LOG INFO "SHUTDOWN_WARNING_SECONDS=%SHUTDOWN_WARNING_SECONDS%"

:: ==================================================
:: PC ID
:: ==================================================
call :LOG STEP "Reading PC ID"
if not exist "%PCIDFILE%" (
    call :LOG ERROR "pc_id.txt not found"
    pause
    goto HOLD
)
set /p PCID=<"%PCIDFILE%"
call :LOG INFO "PC ID=%PCID%"

:: ==================================================
:: CPU LOAD
:: ==================================================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

call :LOG INFO "CPU cores=%CORES%"
call :LOG INFO "Load workers=%LOAD%"

:: ==================================================
:: START CPU LOAD
:: ==================================================
if exist "%PIDFILE%" del "%PIDFILE%"
call :LOG STEP "Starting CPU load"

for /L %%A in (1,1,%LOAD%) do (
    call :LOG DEBUG "Starting worker %%A"
    powershell -NoProfile -Command ^
    "$p=Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile -Command while($true){Start-Sleep -Milliseconds 10}';Add-Content '%PIDFILE%' $p.Id"
)

call :LOG OK "CPU load started"

:: ==================================================
:: WARM-UP LOOP
:: ==================================================
set REMAIN=%WARMUP_SECONDS%
color 0B
call :LOG STEP "Entering warm-up"

:COUNTDOWN
echo Remaining warm-up: %REMAIN% sec
call :LOG DEBUG "Remaining=%REMAIN%"
if %REMAIN% LEQ 0 goto FINISH
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto COUNTDOWN

:: ==================================================
:: FINISH
:: ==================================================
:FINISH
color 07
call :LOG STEP "Warm-up completed"

:: ==================================================
:: STOP CPU LOAD
:: ==================================================
call :LOG STEP "Stopping CPU load"

if exist "%PIDFILE%" (
    for /f %%P in (%PIDFILE%) do (
        call :LOG DEBUG "Stopping PID %%P"
        powershell -NoProfile -Command "Stop-Process -Id %%P -Force -ErrorAction SilentlyContinue"
    )
    del "%PIDFILE%"
)

call :LOG OK "CPU load stopped"

:: ==================================================
:: SHUTDOWN
:: ==================================================
call :LOG STEP "Shutdown scheduled"
call :LOG INFO "SCRIPT END %date% %time%"

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Use shutdown /a to cancel."

:: ==================================================
:: HOLD WINDOW (NO AUTO-CLOSE)
:: ==================================================
:HOLD
echo.
echo =============================================
echo   Script is active. Waiting for shutdown.
echo =============================================
pause >nul
goto HOLD
