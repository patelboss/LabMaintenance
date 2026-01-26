@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Master Production v1.2

:: ==================================================
:: [1] DYNAMIC PATH SETUP
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_active.tmp"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1
if exist "%SIGNAL%" del "%SIGNAL%"

:: ==================================================
:: [2] IDENTITY & ADMIN VERIFICATION
:: ==================================================
if not exist "%PCIDFILE%" (
    cls
    echo Enter PC ID (e.g., LAB-01):
    set /p "NEW_ID="
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"

net session >nul 2>&1 || (
    color 0C & echo [ERROR] Run as Administrator & pause & exit /b
)

:: ==================================================
:: [3] PRE-RUN: DATA COLLECTION (The Fix)
:: ==================================================
echo [STEP] Auditing System...

:: Get Hardware via PowerShell
for /f "delims=" %%A in ('powershell -command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD_NAME=%%A"
for /f "delims=" %%B in ('powershell -command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE_NAME=%%B"

set "HW_STATUS=PASS"
if not defined KBD_NAME (set "HW_STATUS=FAIL (KBD)" & set "KBD_NAME=MISSING")
if not defined MSE_NAME (set "HW_STATUS=FAIL (MOUSE)" & set "MSE_NAME=MISSING")

:: Get DATE & TIME via PowerShell (Fixes the garbled ~0,4 text)
for /f "tokens=1,2" %%A in ('powershell -command "Get-Date -Format 'yyyy-MM-dd HHmmss'"') do (
    set "F_DATE=%%A"
    set "F_TIME_STAMP=%%B"
)
set "F_MONTH=%F_DATE:~0,7%"
set "START_TIME=%time%"

:: Get RAM & Disk via PowerShell
for /f %%M in ('powershell -command "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)"') do set "MEM=%%M"
for /f %%G in ('powershell -command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB)"') do set "FREE_GB=%%G"

:: Create Daily Health File
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_%F_TIME_STAMP%.txt"

(
    echo PC ID: %PCID%
    echo Date: %F_DATE%
    echo Keyboard: %KBD_NAME%
    echo Mouse: %MSE_NAME%
    echo Start RAM: %MEM% MB
    echo ---
)> "%HEALTHFILE%"

:: ==================================================
:: [4] EXECUTION: WARM-UP
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1
echo active > "%SIGNAL%"
for /L %%A in (1,1,%LOAD%) do (
    start "WORKER" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

set "REMAIN=15"
color 0B
:WARMUP_LOOP
cls
echo [PC: %PCID%] [MODE: WARM-UP] %REMAIN%s remaining
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:: ==================================================
:: [5] FINALIZATION & MONTHLY REPORT
:: ==================================================
if exist "%SIGNAL%" del "%SIGNAL%"
color 07
set "END_TIME=%time%"

(
    echo End Time: %END_TIME%
    echo Final Free Disk: %FREE_GB% GB
    echo Status: SUCCESS
)>>"%HEALTHFILE%"

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
    echo HW Audit: %HW_STATUS% (K:%KBD_NAME% M:%MSE_NAME%)
    echo Last Free Space: %FREE_GB% GB
)> "%MONTHLYFILE%"

echo [OK] Reports updated. Success: %PCID% >> "%LOGFILE%"
echo Maintenance Complete. System will shutdown in 60s.
shutdown /s /t 60 /c "Maintenance Complete."
pause
exit /b
