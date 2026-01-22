@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Stable Execution Mode

echo ==================================================
echo   LAB MAINTENANCE SCRIPT INITIALIZING
echo ==================================================
echo If you can read this, the script has started.
echo.

:: ==================================================
:: BASE LOCATION
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "PIDFILE=%BASEDIR%\cpu_pids.txt"
set "HEALTHDIR=%BASEDIR%\Health"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1

:: ==================================================
:: LOG FILE INIT
:: ==================================================
echo Log test > "%BASEDIR%\.__log_test.tmp" 2>nul
if exist "%BASEDIR%\.__log_test.tmp" (
    del "%BASEDIR%\.__log_test.tmp"
    type nul >> "%LOGFILE%"
    >>"%LOGFILE%" echo ===== SCRIPT START %date% %time% =====
    set LOGMODE=FILE
) else (
    echo [WARN] Cannot write log file. Screen-only logging.
    set LOGMODE=SCREEN
)

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [STEP] Verifying administrator rights
if "%LOGMODE%"=="FILE" >>"%LOGFILE%" echo [STEP] Verifying administrator rights

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Administrator rights required
    if "%LOGMODE%"=="FILE" >>"%LOGFILE%" echo [ERROR] Administrator rights required
    pause
    goto HOLD
)

echo [OK] Administrator rights confirmed
if "%LOGMODE%"=="FILE" >>"%LOGFILE%" echo [OK] Administrator rights confirmed

:: ==================================================
:: CONFIGURATION
:: ==================================================
set WARMUP_SECONDS=20
set COOLDOWN_SECONDS=20
set SHUTDOWN_WARNING_SECONDS=120

:: ==================================================
:: PC ID
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [SETUP] Enter PC ID:
    set /p PCID=
    echo %PCID% > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"

:: ==================================================
:: PRE-RUN: SYSTEM DATA COLLECTION
:: ==================================================
:: Safe Date for Filename (YYYY-MM-DD)
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%I"
set "F_DATE=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!"
set "START_TIME=%time%"

:: Create Health File with Timestamped Name
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_!time:~0,2!!time:~3,2!.txt"
set "HEALTHFILE=%HEALTHFILE: =0%"

echo [STEP] Gathering Pre-Maintenance Vitals...

:: 1. Get RAM
set "MEM=Unknown"
for /f "tokens=2 delims==" %%M in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (
    set /a "MEM=%%M / 1024"
)

:: 2. Get Temperature (Safe-Pass Logic)
set "TEMP=Not Supported"
for /f "tokens=2 delims==" %%T in ('wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2^>nul') do (
    set /a "temp_raw=%%T"
    :: Convert Kelvin to Celsius: (K / 10) - 273
    set /a "TEMP=(!temp_raw! / 10) - 273"
)

:: 3. Get Uptime
set "BOOT_RAW=Unknown"
for /f "tokens=2 delims==" %%B in ('wmic os get lastbootuptime /value 2^>nul') do set "BOOT_RAW=%%B"

:: Write Start Report
(
    echo PC ID: %PCID%
    echo Date: %F_DATE%
    echo Start Time: %START_TIME%
    echo System Booted: %BOOT_RAW:~0,4%-%BOOT_RAW:~4,2%-%BOOT_RAW:~6,2% %BOOT_RAW:~8,2%:%BOOT_RAW:~10,2%
    echo Start RAM Available: %MEM% MB
    echo CPU Temperature: %TEMP% C
    echo ---
)> "%HEALTHFILE%"

echo [OK] Health summary saved
>>"%LOGFILE%" echo [OK] Health summary saved: %HEALTHFILE% 2>nul
:: ==================================================
:: CPU LOAD CALCULATION
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

:: ==================================================
:: START CPU LOAD
:: ==================================================
for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_CPU_LOAD" /min cmd /c "for /L %%i in () do rem"
)

:: ==================================================
:: WARM-UP TIMER
:: ==================================================
set REMAIN=%WARMUP_SECONDS%
color 0B
:WARMUP_LOOP
cls
echo WARM-UP: %REMAIN% sec remaining
if %REMAIN% LEQ 0 goto WARMUP_DONE
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto WARMUP_LOOP

:WARMUP_DONE
color 07

:: STOP CPU LOAD
taskkill /F /FI "WINDOWTITLE eq MAINT_CPU_LOAD*" /IM cmd.exe >nul 2>&1

:: ==================================================
:: COOLDOWN TIMER
:: ==================================================
set CD=%COOLDOWN_SECONDS%
color 0A
:COOLDOWN_LOOP
cls
echo COOLDOWN: %CD% sec remaining
if %CD% LEQ 0 goto COOLDOWN_DONE
timeout /t 1 /nobreak >nul
set /a CD-=1
goto COOLDOWN_LOOP

:COOLDOWN_DONE
color 07
:: Disk Check
for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value 2^>nul') do set "FREE_BYTES=%%D"
set /a FREE_GB=%FREE_BYTES:~0,-6% / 1000 2>nul

(
    echo End Time: %END_TIME%
    echo Final Free Disk: %FREE_GB% GB
    echo Status: SUCCESS
)>>"%HEALTHFILE%"
:: ==================================================
:: SHUTDOWN
:: ==================================================
if "%LOGMODE%"=="FILE" (
    >>"%LOGFILE%" echo ===== SCRIPT END %date% %time% =====
)

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Use shutdown /a to cancel."

:HOLD
pause >nul
goto HOLD