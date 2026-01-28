@echo off
setlocal EnableExtensions EnableDelayedExpansion
title PC Health Core - Final Fix

:: --- [1] FORCE DIRECTORY SETUP ---
:: We use the root of the drive to avoid permission issues
set "BASEDIR=C:\Lab_Maintenance"
set "HEALTHDIR=%BASEDIR%\Health"
set "LOGFILE=%BASEDIR%\health.log"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" 2>nul
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" 2>nul

:: Clear screen and start
cls
echo ==================================================
echo   PC HEALTH CORE - STARTING DIAGNOSTIC
echo ==================================================

:: --- [2] WRITE TEST ---
echo [%time%] Initializing... > "%LOGFILE%"
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Cannot write to %BASEDIR%
    echo Please ensure you are running as Administrator.
    pause
    exit /b
)
echo [OK] Write permissions verified.

:: --- [3] ONE-SHOT DATA GATHERING ---
echo [STEP] Gathering Health Data (PowerShell)...
echo [%time%] INFO: Querying System... >> "%LOGFILE%"

:: We gather everything in ONE call to prevent crashes
for /f "tokens=1-4" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$d=Get-Date -Format 'ddMMyyyyHHmm'; ^
  $m=[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024); ^
  $s=[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB); ^
  $h=Get-Date -Format 'MM-yyyy'; ^
  write-host $d $m $s $h"') do (
    set "TS=%%A"
    set "RAM=%%B"
    set "DISK=%%C"
    set "MONTH=%%D"
)

:: --- [4] HARDWARE CHECK ---
echo [STEP] Checking Peripherals...
for /f "delims=" %%K in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD=%%K"
for /f "delims=" %%M in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE=%%M"

if not defined KBD set "KBD=NOT_FOUND"
if not defined MSE set "MSE=NOT_FOUND"

:: --- [5] LIVE LOG OUTPUT ---
echo.
echo --------------------------------------------------
echo   LIVE RESULTS:
echo --------------------------------------------------
echo   TIMESTAMP: %TS%
echo   FREE RAM:  %RAM% MB
echo   FREE DISK: %DISK% GB
echo   KEYBOARD:  %KBD%
echo   MOUSE:     %MSE%
echo --------------------------------------------------
echo.

:: --- [6] REPORT GENERATION ---
set "REPFIL=%HEALTHDIR%\Health_%TS%.txt"
(
    echo PC HEALTH REPORT
    echo Date: %date% %time%
    echo RAM: %RAM% MB
    echo Disk: %DISK% GB
    echo KBD: %KBD%
    echo MSE: %MSE%
) > "%REPFIL%"

if exist "%REPFIL%" (
    echo [SUCCESS] Report saved to %REPFIL%
    echo [%time%] SUCCESS: Report Created >> "%LOGFILE%"
) else (
    echo [FAIL] Report could not be saved.
    echo [%time%] ERROR: File creation failed >> "%LOGFILE%"
)

echo.
echo View Logs at: %LOGFILE%
echo Press any key to close.
pause
