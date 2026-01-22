@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production (Cooldown + Full Logs)

:: ==================================================
:: BASE PATHS
:: ==================================================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health
set MONTHLYDIR=%HEALTHDIR%\Monthly
set PIDFILE=%BASEDIR%\cpu_pids.txt

if not exist "%BASEDIR%" mkdir "%BASEDIR%"
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%"

:: ==================================================
:: ENSURE LOG FILE EXISTS
:: ==================================================
if not exist "%LOGFILE%" echo. > "%LOGFILE%"

:: ==================================================
:: GET SAFE DATE/TIME (LOCALE-INDEPENDENT)
:: ==================================================
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format \"yyyy-MM-dd HH:mm:ss\""' ) do set NOW=%%T

:: ==================================================
:: LOG FUNCTION (SCREEN + FILE)
:: ==================================================
:LOG
:: usage: call :LOG LEVEL MESSAGE
set "LEVEL=%~1"
set "MSG=%~2"
echo [%LEVEL%] %MSG%
echo [%LEVEL%] %MSG%>>"%LOGFILE%"
exit /b

:: ==================================================
:: SCRIPT START
:: ==================================================
call :LOG INFO "SCRIPT START at %NOW%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
call :LOG ACTION "Checking administrator rights"
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
set COOLDOWN_SECONDS=20
set SHUTDOWN_WARNING_SECONDS=20

call :LOG INFO "Configuration loaded"
call :LOG DEBUG "WARMUP_SECONDS=%WARMUP_SECONDS%"
call :LOG DEBUG "COOLDOWN_SECONDS=%COOLDOWN_SECONDS%"
call :LOG DEBUG "SHUTDOWN_WARNING_SECONDS=%SHUTDOWN_WARNING_SECONDS%"

:: ==================================================
:: PC ID
:: ==================================================
call :LOG ACTION "Reading PC ID"
if not exist "%PCIDFILE%" (
    call :LOG ERROR "pc_id.txt missing"
    pause
    exit /b 1
)
set /p PCID=<"%PCIDFILE%"
call :LOG INFO "PC ID=%PCID%"

:: ==================================================
:: CPU LOAD CALCULATION
:: ==================================================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

call :LOG INFO "CPU cores detected=%CORES%"
call :LOG INFO "CPU load workers=%LOAD%"

:: ==================================================
:: START CPU LOAD
:: ==================================================
if exist "%PIDFILE%" del "%PIDFILE%"
call :LOG ACTION "Starting CPU load"

for /L %%A in (1,1,%LOAD%) do (
    call :LOG DEBUG "Starting load worker %%A"
    powershell -NoProfile -Command "$p=Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile -Command while($true){Start-Sleep -Milliseconds 10}';Add-Content '%PIDFILE%' $p.Id"
)

call :LOG INFO "CPU load running"

:: ==================================================
:: WARM-UP LOOP
:: ==================================================
set REMAIN=%WARMUP_SECONDS%
color 0B
call :LOG ACTION "Entering warm-up phase"

:COUNTDOWN
if %REMAIN% LEQ 0 goto FINISH
echo Warm-up remaining: %REMAIN% second(s)
powershell -NoProfile -Command "Start-Sleep -Seconds 1"
set /a REMAIN-=1
goto COUNTDOWN

:: ==================================================
:: FINISH WARM-UP
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
:: COOL-DOWN PHASE
:: ==================================================
call :LOG ACTION "Cool-down started (%COOLDOWN_SECONDS% seconds)"
powershell -NoProfile -Command "Start-Sleep -Seconds %COOLDOWN_SECONDS%"
call :LOG ACTION "Cool-down completed"

:: ==================================================
:: SHUTDOWN
:: ==================================================
call :LOG ACTION "Shutdown timer started"
call :LOG INFO "SCRIPT END"

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."
exit /b 0
