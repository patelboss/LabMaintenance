@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Final Production (Win11 Fix)

:: ==================================================
:: [1] PATHS & AUTO-SETUP
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_active.tmp"

:: Ensure folders exist
if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1
if exist "%SIGNAL%" del "%SIGNAL%"

:: ==================================================
:: [2] IDENTITY & ADMIN
:: ==================================================
if not exist "%PCIDFILE%" (
    set /p "NEW_ID=Enter PC ID: "
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"

net session >nul 2>&1
if errorlevel 1 (
    color 0C & echo [ERROR] Run as Administrator. & pause & exit /b
)

:: ==================================================
:: [3] PRE-RUN: DEVICE AUDIT & DATA COLLECTION
:: ==================================================
echo [STEP] Auditing Hardware...
set "HW_STATUS=PASS"
wmic path Win32_Keyboard get Status 2>nul | findstr /i "OK" >nul
if errorlevel 1 set "HW_STATUS=FAIL (KBD)"
wmic path Win32_PointingDevice get Status 2>nul | findstr /i "OK" >nul
if errorlevel 1 set "HW_STATUS=FAIL (MOUSE)"

:: Safe Date/Time
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%I"
set "F_DATE=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!"
set "F_MONTH=!dt:~0,4!-!dt:~4,2!"
set "START_TIME=%time%"

:: Create Health File
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
:: [4] EXECUTION: WARM-UP (INSTANT Q-EXIT)
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1
echo active > "%SIGNAL%"

:: Start workers and redirect output to NUL to prevent screen freezing
for /L %%A in (1,1,%LOAD%) do (
    start /b cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)" >nul 2>&1
)

set "REMAIN=20"
color 0B
:WARMUP_LOOP
cls
echo ==================================================
echo   MODE: WARM-UP (PC: %PCID%)
echo ==================================================
echo   TIME REMAINING: %REMAIN%s
echo   STATUS: STRESSING HARDWARE (%LOAD% Workers)
echo ==================================================
echo.
echo   [!] PRESS 'Q' TO QUIT IMMEDIATELY
echo.

:: 1-second timer gate
choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:: ==================================================
:: [5] EXECUTION: COOLDOWN
:: ==================================================
if exist "%SIGNAL%" del "%SIGNAL%"
set "CD=20"
color 0A
:CD_LOOP
cls
echo ==================================================
echo   MODE: COOLDOWN (STABILIZING)
echo ==================================================
echo   TIME REMAINING: %CD%s
echo   STATUS: WORKERS STOPPED
echo ==================================================
timeout /t 1 /nobreak >nul
set /a CD-=1
if %CD% GTR 0 goto CD_LOOP

:: ==================================================
:: [6] FINALIZATION & LOGGING
:: ==================================================
color 07
set "END_TIME=%time%"

:: Disk Check
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

echo [OK] All logs and reports updated.
echo %date% %time% - Successful Cycle: %PCID% >> "%LOGFILE%"

:: ==================================================
:: [7] SHUTDOWN CANCEL
:: ==================================================
echo.
echo ==================================================
echo   MAINTENANCE COMPLETE
echo ==================================================
echo   System will shutdown in 60 seconds.
echo   PRESS 'C' TO CANCEL AND STAY ON PC.
echo ==================================================

shutdown /s /t 60 /c "Maintenance Complete."

choice /c c /t 60 /d c /n >nul 2>&1
if !errorlevel! equ 1 (
    shutdown /a >nul 2>&1
    cls & color 0E
    echo [OK] Shutdown Aborted.
    timeout /t 5 >nul
    exit /b
)
exit /b

:: ==================================================
:: [8] THE GRACEFUL ABORT HANDLER
:: ==================================================
:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%"
cls & color 0C
echo [!] ABORT SIGNAL RECEIVED.
echo [!] Stopping Workers...
echo %date% %time% - USER ABORTED CYCLE: %PCID% >> "%LOGFILE%"
timeout /t 3 /nobreak >nul
exit /b
