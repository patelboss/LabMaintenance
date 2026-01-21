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

:: ==================================================
:: CREATE DIRECTORIES (WITH PERMISSION LOGS)
:: ==================================================
if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1

:: ==================================================
:: ENSURE LOG FILE EXISTS
:: ==================================================
echo. > "%LOGFILE%" 2>nul
if not exist "%LOGFILE%" (
    echo [ERROR] Cannot create log file. Permission denied.
    pause
    exit /b 1
)

:: ==================================================
:: LOG FUNCTION
:: ==================================================
:LOG
:: Usage: call :LOG LEVEL MESSAGE
set "LEVEL=%~1"
set "MESSAGE=%~2"
echo [%LEVEL%] %MESSAGE%
echo [%LEVEL%] %MESSAGE%>>"%LOGFILE%"
exit /b

:: ==================================================
:: SCRIPT START
:: ==================================================
call :LOG INFO "SCRIPT START %date% %time%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
call :LOG ACTION "Checking administrator privileges"
net session >nul 2>&1
if %errorlevel% neq 0 (
    call :LOG ERROR "Administrator rights NOT present"
    pause
    exit /b 1
)
call :LOG INFO "Administrator rights confirmed"

:: ==================================================
:: CONFIGURATION
:: ==================================================
set WARMUP_SECONDS=20
set SHUTDOWN_WARNING_SECONDS=20
call :LOG DEBUG "Config WARMUP_SECONDS=%WARMUP_SECONDS%"
call :LOG DEBUG "Config SHUTDOWN_WARNING_SECONDS=%SHUTDOWN_WARNING_SECONDS%"

:: ==================================================
:: FILE PERMISSION CHECKS
:: ==================================================
call :LOG ACTION "Checking write permission in BASEDIR"
echo test > "%BASEDIR%\.__perm_test.tmp" 2>nul
if exist "%BASEDIR%\.__perm_test.tmp" (
    call :LOG PERM "Write permission: OK"
    del "%BASEDIR%\.__perm_test.tmp"
) else (
    call :LOG ERROR "Write permission: FAILED"
    pause
    exit /b 1
)

:: ==================================================
:: PC ID READ
:: ==================================================
call :LOG ACTION "Reading PC ID file"
if not exist "%PCIDFILE%" (
    call :LOG ERROR "pc_id.txt not found"
    pause
    exit /b 1
)

set /p PCID=<"%PCIDFILE%"
call :LOG INFO "PC ID read successfully: %PCID%"

:: ==================================================
:: CPU LOAD CALCULATION
:: ==================================================
set CORES=%NUMBER_OF_PROCESSORS%
call :LOG DEBUG "Detected CPU cores=%CORES%"

set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1
call :LOG INFO "CPU load workers=%LOAD%"

:: ==================================================
:: START CPU LOAD
:: ==================================================
call :LOG ACTION "Starting CPU load processes"
if exist "%PIDFILE%" del "%PIDFILE%"

for /L %%A in (1,1,%LOAD%) do (
    call :LOG DEBUG "Starting worker %%A"
    powershell -NoProfile -Command "$p=Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile -Command while($true){Start-Sleep -Milliseconds 10}';Add-Content '%PIDFILE%' $p.Id"
)

call :LOG INFO "CPU load started"

:: ==================================================
:: WARM-UP LOOP
:: ==================================================
call :LOG ACTION "Entering warm-up loop"
set REMAIN=%WARMUP_SECONDS%
color 0B

:COUNTDOWN
call :LOG DEBUG "Warm-up remaining=%REMAIN% seconds"
echo Remaining warm-up time: %REMAIN% second(s)

if %REMAIN% LEQ 0 goto FINISH
powershell -NoProfile -Command "Start-Sleep -Seconds 1"
set /a REMAIN-=1
goto COUNTDOWN

:: ==================================================
:: FINISH
:: ==================================================
:FINISH
color 07
call :LOG ACTION "Warm-up completed"

:: ==================================================
:: STOP CPU LOAD
:: ==================================================
call :LOG ACTION "Stopping CPU load"

if exist "%PIDFILE%" (
    for /f %%P in (%PIDFILE%) do (
        call :LOG DEBUG "Stopping PID %%P"
        powershell -NoProfile -Command "Stop-Process -Id %%P -Force -ErrorAction SilentlyContinue"
    )
    del "%PIDFILE%"
)

call :LOG INFO "CPU load stopped"

:: ==================================================
:: SHUTDOWN
:: ==================================================
call :LOG ACTION "Initiating shutdown sequence"
call :LOG INFO "SCRIPT END %date% %time%"

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."
exit /b 0
