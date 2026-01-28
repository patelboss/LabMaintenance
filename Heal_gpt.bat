@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Health Core v6.0 - Windows 11 Native

:: --- [1] PATHS ---
set "BASEDIR=C:\Lab_Maintenance"
set "HEALTHDIR=%BASEDIR%\Health"
set "LOGFILE=%BASEDIR%\health.log"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" 2>nul
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" 2>nul

cls
echo ==================================================
echo   PC HEALTH CORE - WINDOWS 11 NATIVE (CIM)
echo ==================================================

:: --- [2] SYSTEM DATA (Using Get-CimInstance) ---
echo [STEP 1] Fetching Time and Date...
for /f "tokens=1-2" %%A in ('powershell -NoProfile -Command "Get-Date -Format 'ddMMyyyyHHmm MM-yyyy'"') do (
    set "TS=%%A"
    set "MONTH=%%B"
)
echo [OK] Timestamp: %TS%
echo [%time%] INFO: Time captured >> "%LOGFILE%"

echo [STEP 2] Fetching RAM (CIM Mode)...
for /f %%M in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)"') do set "RAM=%%M"
echo [OK] RAM: %RAM% MB
echo [%time%] INFO: RAM captured >> "%LOGFILE%"

echo [STEP 3] Fetching Disk Space (CIM Mode)...
for /f %%D in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB)"') do set "DISK=%%D"
echo [OK] Disk: %DISK% GB
echo [%time%] INFO: Disk captured >> "%LOGFILE%"

:: --- [3] PERIPHERAL CHECK ---
echo [STEP 4] Auditing USB Peripherals...
for /f "delims=" %%K in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD=%%K"
for /f "delims=" %%M in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE=%%M"

if not defined KBD set "KBD=Generic/Internal Keyboard"
if not defined MSE set "MSE=Generic/Internal Mouse"
echo [OK] Hardware Audit Finished.
echo [%time%] INFO: Hardware captured >> "%LOGFILE%"

:: --- [4] RESULTS & SAVING ---
echo.
echo --------------------------------------------------
echo   FINAL HEALTH SNAPSHOT:
echo --------------------------------------------------
echo   TIMESTAMP : %TS%
echo   FREE RAM  : %RAM% MB
echo   FREE DISK : %DISK% GB
echo   KEYBOARD  : %KBD%
echo   MOUSE     : %MSE%
echo --------------------------------------------------

set "REPFIL=%HEALTHDIR%\Health_%TS%.txt"
(
    echo PC HEALTH SNAPSHOT
    echo ------------------
    echo ID: %COMPUTERNAME%
    echo Time: %TS%
    echo RAM:  %RAM% MB
    echo Disk: %DISK% GB
    echo KBD:  %KBD%
    echo MSE:  %MSE%
) > "%REPFIL%"

echo [%time%] SUCCESS: Report saved >> "%LOGFILE%"
echo.
echo Process Complete. File saved in C:\Lab_Maintenance\Health
pause
