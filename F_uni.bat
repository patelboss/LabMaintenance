@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Master Production (Final)

:: ==================================================
:: [1] AUTO-SETUP: DIRECTORY STRUCTURE
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_signal.tmp"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1

:: ==================================================
:: [2] FIRST-RUN: IDENTITY SETUP
:: ==================================================
if not exist "%PCIDFILE%" (
    cls
    echo ==================================================
    echo          FIRST-RUN SETUP: IDENTITY
    echo ==================================================
    set /p "NEW_ID=Enter PC ID (e.g. LAB-01): "
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"

:: ==================================================
:: [3] SYSTEM PRE-FLIGHT & ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if errorlevel 1 (
    color 0C & echo [ERROR] Please Run as Administrator. & pause & exit /b 1
)

:: Hardware Audit (Keyboard/Mouse)
set "HW_STATUS=PASS"
wmic path Win32_Keyboard get Status 2>nul | findstr /i "OK" >nul
if errorlevel 1 set "HW_STATUS=FAIL (KBD)"
wmic path Win32_PointingDevice get Status 2>nul | findstr /i "OK" >nul
if errorlevel 1 set "HW_STATUS=FAIL (MOUSE)"

:: ==================================================
:: [4] CONFIGURATION & DATA COLLECTION
:: ==================================================
set "WARMUP_SECONDS=20"
set "COOLDOWN_SECONDS=20"

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%I"
set "F_DATE=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!"
set "F_MONTH=!dt:~0,4!-!dt:~4,2!"
set "START_TIME=%time%"

set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_!time:~0,2!!time:~3,2!.txt"
set "HEALTHFILE=%HEALTHFILE: =0%"

:: RAM & Temp
set "MEM=Unknown"
for /f "tokens=2 delims==" %%M in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (set /a "MEM=%%M / 1024")
set "TEMP=Not Supported"
for /f "tokens=2 delims==" %%T in ('wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2^>nul') do (
    set /a "temp_raw=%%T"
    set /a "TEMP=(!temp_raw! / 10) - 273"
)

(
    echo PC ID: %PCID%
    echo Date: %F_DATE%
    echo Start Time: %START_TIME%
    echo Hardware Audit: %HW_STATUS%
    echo Start RAM: %MEM% MB
    echo CPU Temp: %TEMP% C
    echo ---
)> "%HEALTHFILE%"

:: ==================================================
:: [6] EXECUTION: WARM-UP (With Instant Q-Exit)
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

if exist "%SIGNAL%" del "%SIGNAL%"
echo go > "%SIGNAL%"
for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_CPU_LOAD" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

set REMAIN=%WARMUP_SECONDS%
color 0B
:WARMUP_LOOP
cls
echo [PC: %PCID%] [MODE: WARM-UP]
echo Status: CPU Stress Active (%LOAD% Workers)
echo Time Remaining: %REMAIN% sec
echo.
echo [!] PRESS 'Q' TO STOP IMMEDIATELY
echo ==================================================

:: Use choice as the 1-second timer gate
choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:WARMUP_DONE
if exist "%SIGNAL%" del "%SIGNAL%"

:: ==================================================
:: [7] EXECUTION: COOLDOWN
:: ==================================================
set CD=%COOLDOWN_SECONDS%
color 0A
:COOLDOWN_LOOP
cls
echo [PC: %PCID%] [MODE: COOLDOWN]
echo Status: Stabilizing Thermal Levels...
echo Time Remaining: %CD% sec
if %CD% LEQ 0 goto COOLDOWN_DONE
timeout /t 1 /nobreak >nul
set /a CD-=1
goto COOLDOWN_LOOP

:COOLDOWN_DONE
color 07
set "END_TIME=%time%"

:: ==================================================
:: [8] POST-RUN: REPORTS
:: ==================================================
for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value 2^>nul') do set "FREE_BYTES=%%D"
set /a FREE_GB=%FREE_BYTES:~0,-6% / 1000 2>nul

(
    echo End Time: %END_TIME%
    echo Final Free Disk: %FREE_GB% GB
    echo Status: SUCCESS
)>>"%HEALTHFILE%"

:: Monthly Summary
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
    echo HW Audit: %HW_STATUS%
    echo Last Free Space: %FREE_GB% GB
)> "%MONTHLYFILE%"

:: ==================================================
:: [9] SMART SHUTDOWN
:: ==================================================
echo.
echo [COMPLETE] All logs and health data saved.
>>"%LOGFILE%" echo [OK] Cycle Completed. Health: %HEALTHFILE%

shutdown /s /t 120 /c "Maintenance on %PCID% complete."

echo ==================================================
echo System will shutdown in 2 minutes.
echo PRESS 'C' TO CANCEL AND STAY ON PC.
echo ==================================================

choice /c c /t 60 /d c /n >nul 2>&1
if !errorlevel! equ 1 (
    shutdown /a >nul 2>&1
    cls & color 0E & echo [OK] Shutdown Cancelled.
    timeout /t 10 >nul
    exit /b
)
exit /b

:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%"
cls & color 0C
echo [!] ABORTED. Workers Stopped.
echo %date% %time% - User Aborted >> "%LOGFILE%"
timeout /t 3 >nul
exit /b
