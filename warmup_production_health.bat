@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Health Feature (Stable)

:: ==================================================
:: PATHS & IDENTITY
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "HEALTHDIR=%BASEDIR%\Health"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "SIGNAL=%temp%\maint_stop.tmp"

if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" /p

:: Get/Set PC ID
if not exist "%PCIDFILE%" (
    set /p "USER_PCID=Enter ID for this PC: "
    echo !USER_PCID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Administrative rights required.
    pause & exit /b 1
)

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

:: ==================================================
:: EXECUTION: NATIVE CPU LOAD
:: ==================================================
echo [STEP] Starting Stress Test...
echo go > "%SIGNAL%"
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

for /L %%A in (1,1,%LOAD%) do (
    start "Maint_Worker" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

set "REMAIN=20"
color 0B
:COUNTDOWN
cls
echo ==================================================
echo   HEALTH TEST IN PROGRESS: %PCID%
echo   Current Temp: %TEMP% C
echo   Remaining: !REMAIN! seconds
echo ==================================================
if !REMAIN! LEQ 0 goto FINISH
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto COUNTDOWN

:FINISH
color 07
if exist "%SIGNAL%" del "%SIGNAL%"
set "END_TIME=%time%"

:: ==================================================
:: POST-RUN: FINAL CHECKS
:: ==================================================
echo [STEP] Finalizing Report...

:: Disk Check
for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value 2^>nul') do set "FREE_BYTES=%%D"
set /a FREE_GB=%FREE_BYTES:~0,-6% / 1000 2>nul

(
    echo End Time: %END_TIME%
    echo Final Free Disk: %FREE_GB% GB
    echo Status: SUCCESS
)>>"%HEALTHFILE%"

echo [COMPLETE] Report saved to Health folder.
shutdown /s /t 60 /c "Health maintenance complete."
exit /b 0
