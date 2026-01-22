@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production (Cooldown + Full Logs + Permission Check)

:: ==================================================
:: BASE PATHS
:: ==================================================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt
set PIDFILE=%BASEDIR%\cpu_pids.txt

:: ==================================================
:: CREATE BASE DIRECTORY
:: ==================================================
if not exist "%BASEDIR%" (
    mkdir "%BASEDIR%" >nul 2>&1
)

:: ==================================================
:: PERMISSION CHECK (WRITE TEST)
:: ==================================================
set LOG_OK=1
set TESTFILE=%BASEDIR%\.__perm_test.tmp

echo [INFO] Checking write permission for %BASEDIR%

echo test > "%TESTFILE%" 2>nul
if not exist "%TESTFILE%" (
    echo [ERROR] WRITE PERMISSION DENIED for %BASEDIR%
    echo [ERROR] Cannot create log file. Script will stop.
    set LOG_OK=0
) else (
    del "%TESTFILE%"
    echo [INFO] Write permission OK
)

:: ==================================================
:: ENSURE LOG FILE EXISTS
:: ==================================================
if %LOG_OK%==1 (
    if not exist "%LOGFILE%" (
        echo.>"%LOGFILE%" 2>nul
    )
    if not exist "%LOGFILE%" (
        echo [ERROR] Failed to create log file: %LOGFILE%
        echo [ERROR] Script will not continue without logging
        set LOG_OK=0
    )
)

:: ==================================================
:: LOG FUNCTION (SCREEN + FILE IF POSSIBLE)
:: ==================================================
:LOG
set "LEVEL=%~1"
set "MSG=%~2"
echo [%LEVEL%] %MSG%
if %LOG_OK%==1 (
    echo [%LEVEL%] %MSG%>>"%LOGFILE%"
)
exit /b

:: ==================================================
:: HARD STOP IF LOGGING FAILED
:: ==================================================
if %LOG_OK%==0 (
    echo.
    echo =============================================
    echo  CRITICAL ERROR: LOGGING NOT AVAILABLE
    echo  Check folder permissions:
    echo  %BASEDIR%
    echo =============================================
    pause
    goto :EOF
)

:: ==================================================
:: SAFE DATE/TIME
:: ==================================================
for /f "delims=" %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH:mm:ss"') do set NOW=%%T

call :LOG INFO "SCRIPT START at %NOW%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
call :LOG ACTION "Checking administrator rights"
net session >nul 2>&1
if %errorlevel% neq 0 (
    call :LOG ERROR "Administrator rights NOT present"
    pause
    goto HOLD
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
    goto HOLD
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
    powershell -NoProfile -Command ^
    "$p=Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile -Command while($true){Start-Sleep -Milliseconds 10}'; Add-Content '%PIDFILE%' $p.Id"
)

call :LOG INFO "CPU load running"

:: ==================================================
:: WARM-UP
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
:: COOL-DOWN
:: ==================================================
call :LOG ACTION "Cool-down started (%COOLDOWN_SECONDS% seconds)"
powershell -NoProfile -Command "Start-Sleep -Seconds %COOLDOWN_SECONDS%"
call :LOG ACTION "Cool-down completed"

:: ==================================================
:: SHUTDOWN
:: ==================================================
call :LOG ACTION "Shutdown timer started"
call :LOG INFO "SCRIPT END – waiting for shutdown"

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."

:HOLD
echo.
echo =============================================
echo  Script is active. Waiting for shutdown...
echo =============================================
pause >nul
goto HOLD
