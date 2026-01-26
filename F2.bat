@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Master Production v2.0 (Verbose Logging)

:: ==================================================
:: [0] LOGGING FUNCTION
:: ==================================================
:: This local function handles all the heavy lifting for logs
goto :START_SCRIPT
:WRITE_LOG
echo [%time%] %~1
echo [%date% %time%] %~1 >> "%LOGFILE%"
exit /b

:START_SCRIPT
:: ==================================================
:: [1] DYNAMIC PATH SETUP
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_active.tmp"

mkdir "%BASEDIR%" >nul 2>&1
mkdir "%HEALTHDIR%" >nul 2>&1
mkdir "%MONTHLYDIR%" >nul 2>&1
if exist "%SIGNAL%" del "%SIGNAL%"

call :WRITE_LOG "--- NEW SESSION STARTED ---"
call :WRITE_LOG "Directories initialized at %BASEDIR%"

:: ==================================================
:: [2] IDENTITY & ADMIN VERIFICATION
:: ==================================================
net session >nul 2>&1
if errorlevel 1 (
    color 0C
    call :WRITE_LOG "CRITICAL ERROR: No Admin Rights. Script cannot proceed."
    echo.
    echo [!] ERROR: Please run as Administrator.
    pause
    goto :GRACEFUL_ABORT
)
call :WRITE_LOG "Admin rights verified."

if not exist "%PCIDFILE%" (
    call :WRITE_LOG "No PC ID found. Prompting user for setup."
    set /p "NEW_ID=Enter PC ID (e.g., LAB-01): "
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"
call :WRITE_LOG "Identity confirmed as: %PCID%"

:: ==================================================
:: [3] PRE-RUN: DEVICE AUDIT & DATA COLLECTION
:: ==================================================
call :WRITE_LOG "Starting Hardware Audit..."

:: Keyboard
call :WRITE_LOG "Searching for Keyboard via PnP..."
for /f "delims=" %%A in ('powershell -command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD_NAME=%%A"
if defined KBD_NAME (call :WRITE_LOG "Keyboard Found: %KBD_NAME%") else (call :WRITE_LOG "Keyboard NOT FOUND.")

:: Mouse
call :WRITE_LOG "Searching for Mouse/Pointing Devices..."
for /f "delims=" %%B in ('powershell -command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE_NAME=%%B"
if defined MSE_NAME (call :WRITE_LOG "Mouse Found: %MSE_NAME%") else (call :WRITE_LOG "Mouse NOT FOUND.")

:: Health Logic
set "HW_STATUS=PASS"
if not defined KBD_NAME (set "HW_STATUS=FAIL (KBD)" & set "KBD_NAME=MISSING")
if not defined MSE_NAME (set "HW_STATUS=FAIL (MOUSE)" & set "MSE_NAME=MISSING")

:: Date/Time Replacement for WMIC
call :WRITE_LOG "Fetching system date/time via PowerShell..."
for /f "tokens=1,2" %%A in ('powershell -command "Get-Date -Format 'yyyy-MM-dd HHmmss'"') do (
    set "F_DATE=%%A"
    set "F_TIME=%%B"
)
set "F_MONTH=%F_DATE:~0,7%"
set "START_TIME=%time%"
call :WRITE_LOG "Timestamp set to %F_DATE% %F_TIME%"

:: RAM & Temp (PowerShell Replacement)
call :WRITE_LOG "Calculating Free RAM..."
for /f %%M in ('powershell -command "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)"') do set "MEM=%%M"
call :WRITE_LOG "Current Free RAM: %MEM% MB"

call :WRITE_LOG "Querying Thermal Zones..."
for /f %%T in ('powershell -command "$t = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue; if($t){ [math]::Round(($t.CurrentTemperature / 10) - 273) }else{'N/A'}"') do set "TEMP=%%T"
call :WRITE_LOG "CPU Temperature Result: %TEMP% C"

:: Create Daily Health File
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_%F_TIME%.txt"
(
    echo PC ID: %PCID%
    echo Date: %F_DATE%
    echo Start Time: %START_TIME%
    echo Keyboard: %KBD_NAME%
    echo Mouse:    %MSE_NAME%
    echo Start RAM: %MEM% MB
    echo CPU Temp: %TEMP% C
    echo ---
)> "%HEALTHFILE%"
call :WRITE_LOG "Daily Health file created: %HEALTHFILE%"

:: ==================================================
:: [4] EXECUTION: WARM-UP
:: ==================================================
call :WRITE_LOG "Launching CPU Warm-up workers..."
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1
echo active > "%SIGNAL%"

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)
call :WRITE_LOG "Started %LOAD% worker threads."

set "REMAIN=20"
color 0B
:WARMUP_LOOP
cls
echo [MODE: WARM-UP] PC: %PCID% | Time: %REMAIN%s
echo Peripherals: K:%KBD_NAME% M:%MSE_NAME%
echo ------------------------------------------
echo CHECK LOG FILE FOR LIVE STATUS
set /a REMAIN-=1
if %REMAIN% GTR 0 ( timeout /t 1 /nobreak >nul & goto WARMUP_LOOP )

:: ==================================================
:: [5] EXECUTION: COOLDOWN
:: ==================================================
call :WRITE_LOG "Terminating workers (Signal Delete)..."
if exist "%SIGNAL%" del "%SIGNAL%"
set "CD=20"
color 0A
:CD_LOOP
cls
echo [MODE: COOLDOWN] PC: %PCID% | Time: %CD%s
echo Status: Stabilizing System
set /a CD-=1
if %CD% GTR 0 ( timeout /t 1 /nobreak >nul & goto CD_LOOP )
call :WRITE_LOG "Cooldown complete."

:: ==================================================
:: [6] FINALIZATION & REPORTS
:: ==================================================
call :WRITE_LOG "Running Final Storage Audit..."
for /f %%G in ('powershell -command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB)"') do set "FREE_GB=%%G"
call :WRITE_LOG "Final C: Drive Space: %FREE_GB% GB"

(
    echo End Time: %time%
    echo Final Free Disk: %FREE_GB% GB
    echo Status: SUCCESS
)>>"%HEALTHFILE%"

:: Update Monthly Summary
call :WRITE_LOG "Processing Monthly Summary..."
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
    echo Last Run: %F_DATE% %time%
    echo HW Audit: %HW_STATUS% (K:%KBD_NAME% M:%MSE_NAME%)
    echo Last Free Space: %FREE_GB% GB
)> "%MONTHLYFILE%"
call :WRITE_LOG "Monthly report saved. Total runs for this month: %RUN_COUNT%"

:: ==================================================
:: [7] SMART SHUTDOWN
:: ==================================================
call :WRITE_LOG "Triggering Shutdown Timer (60s)."
shutdown /s /t 60 /c "Lab Maintenance on %PCID% complete."

echo.
echo ==================================================
echo   MAINTENANCE COMPLETE - CYCLE SUCCESSFUL
echo ==================================================
echo   System will shutdown in 60 seconds.
echo   PRESS 'C' TO CANCEL.
echo.

choice /c c /t 60 /d c /n >nul 2>&1
if !errorlevel! equ 1 (
    shutdown /a >nul 2>&1
    call :WRITE_LOG "Shutdown cancelled by user at console."
    color 0E
    echo [OK] Shutdown Aborted. Script will exit in 10s.
    timeout /t 10 >nul
)
call :WRITE_LOG "--- SESSION ENDED ---"
exit /b

:: ==================================================
:: [8] THE GRACEFUL ABORT HANDLER
:: ==================================================
:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%"
call :WRITE_LOG "ABORT: Script stopped prematurely."
echo.
echo [!] SCRIPT STOPPED. Check log.txt for details.
pause
exit /b
