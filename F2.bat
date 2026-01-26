@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Master Production (Verbose Live Logs)

:: ==================================================
:: [1] PATH SETUP
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_active.tmp"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1
if exist "%SIGNAL%" del "%SIGNAL%" >nul 2>&1

if not exist "%LOGFILE%" echo.>"%LOGFILE%"

:: ==================================================
:: LOG FUNCTION (SCREEN + FILE)
:: ==================================================
:LOG
echo [%~1] %~2
echo [%~1] %~2>>"%LOGFILE%"
exit /b

call :LOG INFO "================ SCRIPT START ================"

:: ==================================================
:: [2] ADMIN CHECK
:: ==================================================
call :LOG STEP "Checking administrator rights"
net session >nul 2>&1
if errorlevel 1 (
    call :LOG ERROR "Administrator rights REQUIRED"
    pause
    goto HOLD
)
call :LOG OK "Administrator confirmed"

:: ==================================================
:: [3] PC ID
:: ==================================================
call :LOG STEP "Loading PC ID"
if not exist "%PCIDFILE%" (
    call :LOG SETUP "PC ID not found – first run"
    set /p "NEW_ID=Enter PC ID: "
    echo !NEW_ID!>"%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"
call :LOG INFO "PC ID = %PCID%"

:: ==================================================
:: [4] SAFE DATE & TIME (DDMMYYYYHHMM)
:: ==================================================
call :LOG STEP "Generating safe timestamp"
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "DT=%%I"

set "YYYY=!DT:~0,4!"
set "MM=!DT:~4,2!"
set "DD=!DT:~6,2!"
set "HH=!DT:~8,2!"
set "MN=!DT:~10,2!"

set "STAMP=%DD%%MM%%YYYY%%HH%%MN%"
set "MONTHSTAMP=%MM%%YYYY%"

call :LOG INFO "Timestamp = %STAMP%"

:: ==================================================
:: [5] HEALTH FILE INIT
:: ==================================================
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%STAMP%.txt"
call :LOG INFO "Health file path: %HEALTHFILE%"

:: ==================================================
:: [6] HEALTH DATA COLLECTION (VERBOSE)
:: ==================================================
call :LOG STEP "Starting health data collection"

:: ---- RAM ----
call :LOG STEP "Collecting available RAM"
set "MEM=UNKNOWN"
for /f "tokens=2 delims==" %%M in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (
    set /a MEM=%%M/1024
)
call :LOG INFO "RAM detected: %MEM% MB"

:: ---- CPU TEMP ----
call :LOG STEP "Collecting CPU temperature"
set "TEMP=NOT_SUPPORTED"
for /f "tokens=2 delims==" %%T in ('wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2^>nul') do (
    if not "%%T"=="" (
        set /a RAW_TEMP=%%T
        set /a TEMP=(RAW_TEMP/10)-273
    )
)

if "%TEMP%"=="NOT_SUPPORTED" (
    call :LOG WARN "CPU temperature not supported on this system"
) else (
    call :LOG INFO "CPU temperature: %TEMP% C"
)

:: ---- WRITE HEALTH FILE ----
call :LOG STEP "Writing health report to file"
(
echo PC ID: %PCID%
echo Date-Time: %DD%-%MM%-%YYYY% %HH%:%MN%
echo Available RAM: %MEM% MB
echo CPU Temperature: %TEMP%
echo ---
)> "%HEALTHFILE%"

call :LOG OK "Health report created successfully"

:: ==================================================
:: [7] CPU LOAD (WARM-UP)
:: ==================================================
call :LOG STEP "Calculating CPU load"
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1
call :LOG INFO "CPU load workers = %LOAD%"

echo active>"%SIGNAL%"
call :LOG STEP "Starting CPU workers"

for /L %%A in (1,1,%LOAD%) do (
    call :LOG DEBUG "Starting worker %%A"
    start "MAINT_WORKER" /min cmd /c "for /L %%i in () do if not exist "%SIGNAL%" exit"
)

:: ---- WARM-UP LOOP ----
set REMAIN=20
color 0B
:WARMUP
cls
echo === WARM-UP MODE ===
echo PC: %PCID%
echo Remaining: %REMAIN%s
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP

:: ==================================================
:: [8] COOLDOWN
:: ==================================================
call :LOG STEP "Stopping CPU workers"
if exist "%SIGNAL%" del "%SIGNAL%"

set CD=20
color 0A
:COOLDOWN
cls
echo === COOLDOWN MODE ===
echo Remaining: %CD%s
timeout /t 1 /nobreak >nul
set /a CD-=1
if %CD% GTR 0 goto COOLDOWN
color 07

:: ==================================================
:: [9] FINAL HEALTH UPDATE
:: ==================================================
call :LOG STEP "Finalizing health report"

for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value 2^>nul') do set "FREE_BYTES=%%D"
for /f %%G in ('powershell [math]::Round^(%FREE_BYTES%/1GB^)') do set "FREE_GB=%%G"

(
echo End Time: %time%
echo Free Disk: %FREE_GB% GB
echo Status: SUCCESS
)>>"%HEALTHFILE%"

call :LOG OK "Health report finalized"

:: ==================================================
:: [10] MONTHLY REPORT
:: ==================================================
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%MONTHSTAMP%.txt"
call :LOG STEP "Updating monthly report"

if not exist "%MONTHLYFILE%" (
    call :LOG INFO "Creating new monthly report"
    echo MONTHLY SUMMARY %MONTHSTAMP%>"%MONTHLYFILE%"
    echo PC ID: %PCID%>>"%MONTHLYFILE%"
    echo ------------------------------>>"%MONTHLYFILE%"
)

echo %STAMP% | Free: %FREE_GB% GB>>"%MONTHLYFILE%"
call :LOG OK "Monthly report updated"

:: ==================================================
:: [11] SHUTDOWN
:: ==================================================
call :LOG INFO "Maintenance complete – system will shutdown in 60 seconds"
shutdown /s /t 60 /c "Lab Maintenance complete on %PCID%"

:HOLD
echo.
echo === SCRIPT PAUSED (FOR DEBUG) ===
pause
goto HOLD
