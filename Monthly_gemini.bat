@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Stable Execution Mode

echo ==================================================
echo   LAB MAINTENANCE SCRIPT INITIALIZING
echo ==================================================

:: ==================================================
:: BASE LOCATION & FOLDERS
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1

:: ==================================================
:: LOG FILE INIT
:: ==================================================
type nul >> "%LOGFILE%"
>>"%LOGFILE%" echo ===== SCRIPT START %date% %time% =====

:: ==================================================
:: ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Administrator rights required.
    >>"%LOGFILE%" echo [ERROR] Admin Check Failed.
    pause & exit /b 1
)

:: ==================================================
:: CONFIGURATION
:: ==================================================
set WARMUP_SECONDS=20
set COOLDOWN_SECONDS=20
set SHUTDOWN_WARNING_SECONDS=120

:: ==================================================
:: PC ID & DATE HANDLING
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [SETUP] No PC ID found.
    set /p "PCID=Enter PC ID: "
    echo !PCID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"

:: Safe Date (YYYY-MM-DD) and Month (YYYY-MM)
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%I"
set "F_DATE=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!"
set "F_MONTH=!dt:~0,4!-!dt:~4,2!"
set "START_TIME=%time%"

:: ==================================================
:: PRE-RUN: HEALTH COLLECTION
:: ==================================================
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_!time:~0,2!!time:~3,2!.txt"
set "HEALTHFILE=%HEALTHFILE: =0%"

:: 1. RAM & Temperature (Safe Check)
set "MEM=Unknown"
for /f "tokens=2 delims==" %%M in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (set /a "MEM=%%M / 1024")

set "TEMP=Not Supported"
for /f "tokens=2 delims==" %%T in ('wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2^>nul') do (
    set /a "temp_raw=%%T"
    set /a "TEMP=(!temp_raw! / 10) - 273"
)

:: Write Pre-Report
(
    echo PC ID: %PCID%
    echo Date: %F_DATE%
    echo Start Time: %START_TIME%
    echo Start RAM: %MEM% MB
    echo CPU Temp: %TEMP% C
    echo ---
)> "%HEALTHFILE%"

:: ==================================================
:: EXECUTION: WARM-UP (CPU LOAD)
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_CPU_LOAD" /min cmd /c "for /L %%i in () do rem"
)

set REMAIN=%WARMUP_SECONDS%
color 0B
:WARMUP_LOOP
cls
echo [MODE: WARM-UP] PC: %PCID%
echo CPU Load Active: %LOAD% Workers
echo Time Remaining: %REMAIN% sec
if %REMAIN% LEQ 0 goto WARMUP_DONE
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto WARMUP_LOOP

:WARMUP_DONE
taskkill /F /FI "WINDOWTITLE eq MAINT_CPU_LOAD*" /IM cmd.exe >nul 2>&1

:: ==================================================
:: EXECUTION: COOLDOWN
:: ==================================================
set CD=%COOLDOWN_SECONDS%
color 0A
:COOLDOWN_LOOP
cls
echo [MODE: COOLDOWN] PC: %PCID%
echo Systems Stabilizing...
echo Time Remaining: %CD% sec
if %CD% LEQ 0 goto COOLDOWN_DONE
timeout /t 1 /nobreak >nul
set /a CD-=1
goto COOLDOWN_LOOP

:COOLDOWN_DONE
color 07
set "END_TIME=%time%"

:: ==================================================
:: POST-RUN: FINAL REPORTS
:: ==================================================
:: 1. Disk Check
for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value 2^>nul') do set "FREE_BYTES=%%D"
set /a FREE_GB=%FREE_BYTES:~0,-6% / 1000 2>nul

:: Update Health File
(
    echo End Time: %END_TIME%
    echo Final Free Disk: %FREE_GB% GB
    echo Status: SUCCESS
)>>"%HEALTHFILE%"

:: 2. Monthly Report Logic
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%F_MONTH%.txt"
set "RUN_COUNT=0"

if exist "%MONTHLYFILE%" (
    for /f "tokens=3" %%R in ('findstr /C:"Total Runs:" "%MONTHLYFILE%"') do set /a "RUN_COUNT=%%R"
)
set /a "RUN_COUNT+=1"

(
    echo ====================================
    echo   MONTHLY SUMMARY: %F_MONTH%
    echo ====================================
    echo PC ID: %PCID%
    echo Total Runs: %RUN_COUNT%
    echo Last Run: %F_DATE% at %END_TIME%
    echo Last Free Space: %FREE_GB% GB
    echo Last Temp Recorded: %TEMP% C
)> "%MONTHLYFILE%"

:: ==================================================
:: FINAL SHUTDOWN
:: ==================================================
echo [OK] Reports generated successfully.
>>"%LOGFILE%" echo [OK] Cycle Completed. Health: %HEALTHFILE%
>>"%LOGFILE%" echo ===== SCRIPT END %date% %time% =====

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance on %PCID% complete. Check logs in Maintenance_Data folder."
echo.
echo Cycle Finished. PC will shutdown in 2 minutes.
pause
exit /b

