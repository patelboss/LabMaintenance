@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Master v1.0 - Health & Peripheral Audit

:: --- [1] PATHS & FOLDER SETUP ---
set "BASEDIR=C:\Lab_Maintenance"
set "HEALTHDIR=%BASEDIR%\Health"
set "LOGFILE=%BASEDIR%\health.log"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" 2>nul
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" 2>nul

cls
echo ==================================================
echo   LAB MASTER: HEALTH & PERIPHERAL AUDIT
echo ==================================================
echo [%date% %time%] INFO: Starting Master Audit >> "%LOGFILE%"

:: --- [2] SYSTEM DATA (CIM Mode) ---
echo [STEP 1] Fetching Time and Date...
for /f "tokens=1-2" %%A in ('powershell -NoProfile -Command "Get-Date -Format 'ddMMyyyyHHmm MM-yyyy'"') do (
    set "TS=%%A"
    set "MONTHKEY=%%B"
)
echo [OK] Timestamp: %TS%
echo [%time%] INFO: Time captured >> "%LOGFILE%"

echo [STEP 2] Fetching RAM (CIM Mode)...
for /f %%M in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)"') do set "RAM=%%M"
echo [OK] RAM: %RAM% MB
echo [%time%] INFO: RAM captured >> "%LOGFILE%"

echo [STEP 3] Fetching Disk Space 
for /f %%D in ('powershell -NoProfile -Command "$d=(Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:'); if($d){ [math]::Round($d.FreeSpace / 1GB) } else { 0 }"') do set "DISK=%%D"
if not defined DISK set "DISK=ERR"
echo [OK] Disk: %DISK% GB
echo [%time%] INFO: Disk captured >> "%LOGFILE%"


:: --- [3] PERIPHERAL AUDIT (PnP Mode) ---
echo [STEP 4] Auditing USB Peripherals...

:: Keyboard Check
for /f "delims=" %%K in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD_NAME=%%K"
if defined KBD_NAME (set "KBD_STATUS=OK") else (set "KBD_STATUS=MISSING" & set "KBD_NAME=None")

:: Mouse Check
for /f "delims=" %%M in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE_NAME=%%M"
if defined MSE_NAME (set "MSE_STATUS=OK") else (set "MSE_STATUS=MISSING" & set "MSE_NAME=None")

echo [OK] Hardware Audit Finished.
echo [%time%] INFO: Hardware captured (K:%KBD_STATUS% M:%MSE_STATUS%) >> "%LOGFILE%"

:: --- [4] RESULTS & VISUAL FEEDBACK ---
echo.
echo --------------------------------------------------
echo   FINAL AUDIT RESULTS:
echo --------------------------------------------------
echo   FREE RAM  : %RAM% MB
echo   FREE DISK : %DISK% GB
echo.
echo   KEYBOARD  : %KBD_STATUS% (%KBD_NAME%)
echo   MOUSE     : %MSE_STATUS% (%MSE_NAME%)
echo --------------------------------------------------

:: --- [5] SAVE REPORT ---
set "REPFIL=%HEALTHDIR%\Health_%TS%.txt"
(
    echo PC AUDIT REPORT
    echo ------------------
    echo ID        : %COMPUTERNAME%
    echo Time      : %TS%
    echo Month     : %MONTHKEY%
    echo.
    echo [SYSTEM]
    echo RAM FREE  : %RAM% MB
    echo DISK FREE : %DISK% GB
    echo.
    echo [HARDWARE]
    echo KEYBOARD  : %KBD_STATUS% [%KBD_NAME%]
    echo MOUSE     : %MSE_STATUS% [%MSE_NAME%]
) > "%REPFIL%"

:: --- [6] ALERT LOGIC (Visual Color) ---
if "%KBD_STATUS%"=="MISSING" (
    color 0C
    echo [!] ALERT: Keyboard is MISSING.
) else if "%MSE_STATUS%"=="MISSING" (
    color 0C
    echo [!] ALERT: Mouse is MISSING.
) else (
    color 0A
    echo [PASS] All systems and hardware are healthy.
)

echo [%time%] SUCCESS: Report saved >> "%LOGFILE%"
echo.
echo Process Complete. File: C:\Lab_Maintenance\Health
pause

