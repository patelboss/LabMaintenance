@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance - EMERGENCY REPAIR MODE

:: ==================================================
:: [1] FORCE FOLDER CREATION
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
mkdir "%BASEDIR%" 2>nul
mkdir "%BASEDIR%\Health" 2>nul
mkdir "%BASEDIR%\Monthly" 2>nul

set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"

:: Test if we can actually write to the log
echo [%time%] Script initializing... > "%LOGFILE%" || (
    color 0C
    echo [CRITICAL ERROR] Cannot write to the folder. 
    echo Please move the script to your Desktop or C:\ folder.
    pause
    exit /b
)

:: ==================================================
:: [2] ADMIN CHECK
:: ==================================================
net session >nul 2>&1 || (
    color 0C
    echo [ERROR] PLEASE RIGHT-CLICK AND 'RUN AS ADMINISTRATOR'
    echo [%time%] ERROR: No Admin Rights >> "%LOGFILE%"
    pause
    exit /b
)

:: ==================================================
:: [3] MODERN DATA COLLECTION (No WMIC)
:: ==================================================
echo [STATUS] Gathering System Data...

:: Get Date, RAM, and Disk using one single PowerShell call (Safest method)
for /f "tokens=1-4" %%A in ('powershell -command "$d=Get-Date -Format 'yyyy-MM-dd HHmm'; $m=[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024); $s=[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB); write-host $d $m $s"') do (
    set "F_DATE=%%A"
    set "F_TIME=%%B"
    set "RAM=%%C"
    set "DISK=%%D"
)
set "F_MONTH=%F_DATE:~0,7%"

:: Get Peripherals
for /f "delims=" %%K in ('powershell -command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD=%%K"
for /f "delims=" %%M in ('powershell -command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE=%%M"

if not defined KBD set "KBD=MISSING"
if not defined MSE set "MSE=MISSING"

:: ==================================================
:: [4] CREATE THE REPORTS
:: ==================================================
set "HEALTHFILE=%BASEDIR%\Health\Health_%F_DATE%_%F_TIME%.txt"

(
    echo PC_DATA_REPORT
    echo Date: %F_DATE%
    echo RAM: %RAM% MB
    echo Disk: %DISK% GB
    echo Keyboard: %KBD%
    echo Mouse: %MSE%
) > "%HEALTHFILE%"

:: Monthly Log (Simplified append)
set "MONTHLYFILE=%BASEDIR%\Monthly\Monthly_%F_MONTH%.txt"
echo [%F_DATE% %time%] RAM:%RAM%MB Disk:%DISK%GB K:%KBD% >> "%MONTHLYFILE%"

:: ================================
:: [5] THE VISUAL PROGRESS
:: ================================
set "REMAIN=10"
:LOOP
cls
color 0B
echo ==========================================
echo   LAB MAINTENANCE ACTIVE
echo ==========================================
echo   DATE: %F_DATE%
echo   RAM:  %RAM% MB
echo   DISK: %DISK% GB
echo   KBD:  %KBD%
echo   MSE:  %MSE%
echo ==========================================
echo   FINISHING IN: %REMAIN%s
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
if %REMAIN% GTR 0 goto :LOOP

echo [%date% %time%] SUCCESSFUL RUN >> "%LOGFILE%"
echo.
echo [COMPLETE] Reports are in the Maintenance_Data folder.
pause
