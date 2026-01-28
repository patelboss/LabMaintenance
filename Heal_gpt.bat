@echo off
setlocal EnableExtensions EnableDelayedExpansion
title PC Health Monitor – Win11 Stable

:: --- [1] DIRECTORY SETUP ---
set "BASEDIR=%~dp0Maintenance_Data"
set "HEALTHDIR=%BASEDIR%\Health"
set "LOGFILE=%BASEDIR%\health_debug.log"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" 2>nul
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" 2>nul

:: Initial log entry
echo [%date% %time%] --- MONITOR START --- > "%LOGFILE%"

echo ==================================================
echo   PC HEALTH MONITOR (LIVE LOGS)
echo ==================================================

:: --- [2] SINGLE DATA PACKET GATHERING ---
echo [STEP] Gathering System Health Data...
echo [%time%] INFO: Executing PowerShell Data Packet... >> "%LOGFILE%"

:: This combined command pulls Date, Month, RAM, and Disk in one go for maximum stability
for /f "tokens=1-4" %%A in ('powershell -NoProfile -Command ^
 "$ts=Get-Date -Format 'ddMMyyyyHHmm'; ^
  $mon=Get-Date -Format 'MM-yyyy'; ^
  $ram=[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024); ^
  $disk=[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB); ^
  write-host $ts $mon $ram $disk"') do (
    set "TS=%%A"
    set "MONTHKEY=%%B"
    set "RAM_MB=%%C"
    set "FREE_GB=%%D"
)

:: Live Log Output
echo [INFO] Timestamp: %TS%
echo [INFO] Month:     %MONTHKEY%
echo [INFO] Free RAM:  %RAM_MB% MB
echo [INFO] Disk Free: %FREE_GB% GB
echo [%time%] DATA: TS=%TS% RAM=%RAM_MB% DISK=%FREE_GB% >> "%LOGFILE%"

:: --- [3] HARDWARE AUDIT (Keyboard/Mouse) ---
echo [STEP] Checking Peripherals...
for /f "delims=" %%K in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD=%%K"
for /f "delims=" %%M in ('powershell -command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE=%%M"

if not defined KBD set "KBD=MISSING"
if not defined MSE set "MSE=MISSING"

echo [INFO] Keyboard:  %KBD%
echo [INFO] Mouse:     %MSE%
echo [%time%] HW: K=%KBD% M=%MSE% >> "%LOGFILE%"

:: --- [4] REPORT CREATION ---
echo [STEP] Creating Health Report...
set "REPORT=%HEALTHDIR%\Health_%TS%.txt"

(
    echo PC HEALTH REPORT
    echo -----------------
    echo TIMESTAMP: %TS%
    echo RAM FREE:  %RAM_MB% MB
    echo DISK FREE: %FREE_GB% GB
    echo KEYBOARD:  %KBD%
    echo MOUSE:     %MSE%
) > "%REPORT%"

if exist "%REPORT%" (
    echo [OK] Report created: %REPORT%
    echo [%time%] SUCCESS: Report saved >> "%LOGFILE%"
) else (
    echo [ERROR] Failed to save report.
    echo [%time%] ERROR: File creation failed >> "%LOGFILE%"
)

echo.
echo ==================================================
echo   MONITORING COMPLETE
echo   Logs: %LOGFILE%
echo ==================================================
pause
