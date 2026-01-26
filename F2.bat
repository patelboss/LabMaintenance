@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Master Production v2.1

:: ==================================================
:: [1] DIRECTORY SETUP (Aggressive)
:: ==================================================
set "DATA_NAME=Maintenance_Data"
set "BASEDIR=%~dp0%DATA_NAME%"

:: Create folders directly
if not exist "%BASEDIR%" mkdir "%BASEDIR%"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_active.tmp"

mkdir "%HEALTHDIR%" 2>nul
mkdir "%MONTHLYDIR%" 2>nul
if exist "%SIGNAL%" del "%SIGNAL%"

:: Write first log line immediately to verify write access
echo [%date% %time%] --- STARTING v2.1 --- >> "%LOGFILE%"
echo [OK] Directories initialized.

:: ==================================================
:: [2] ADMIN & IDENTITY
:: ==================================================
net session >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] YOU MUST RUN THIS AS ADMINISTRATOR.
    echo [%date% %time%] FAILED: No Admin Rights >> "%LOGFILE%"
    pause
    exit /b
)

if not exist "%PCIDFILE%" (
    echo First run detected.
    set /p "NEW_ID=Enter PC ID (e.g., LAB-01): "
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"
echo [OK] PC ID set to %PCID%

:: ==================================================
:: [3] DATA COLLECTION (PowerShell Only)
:: ==================================================
echo [STEP] Auditing Hardware...
echo [%time%] Searching PnP Devices... >> "%LOGFILE%"

for /f "delims=" %%A in ('powershell -command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD_NAME=%%A"
for /f "delims=" %%B in ('powershell -command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE_NAME=%%B"

if not defined KBD_NAME set "KBD_NAME=MISSING"
if not defined MSE_NAME set "MSE_NAME=MISSING"
echo [%time%] Found: K:%KBD_NAME% M:%MSE_NAME% >> "%LOGFILE%"

:: Get Date/Time/RAM/Disk all at once via PowerShell
echo [%time%] Gathering System Stats... >> "%LOGFILE%"
for /f "tokens=1-4" %%A in ('powershell -command "$d=Get-Date -Format 'yyyy-MM-dd HHmmss'; $m=[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024); $s=[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB); write-host $d $m $s"') do (
    set "F_DATE=%%A"
    set "F_TIME=%%B"
    set "MEM=%%C"
    set "DISK=%%D"
)
set "F_MONTH=%F_DATE:~0,7%"

set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_%F_TIME%.txt"

(
    echo PC ID: %PCID%
    echo Date: %F_DATE%
    echo Keyboard: %KBD_NAME%
    echo Mouse: %MSE_NAME%
    echo RAM: %MEM% MB
    echo Disk: %DISK% GB
) > "%HEALTHFILE%"
echo [%time%] Health report created. >> "%LOGFILE%"

:: ==================================================
:: [4] WARM-UP LOOP
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1
echo active > "%SIGNAL%"

for /L %%A in (1,1,%LOAD%) do (
    start "WORKER" /min cmd /c " :LOOP & if exist "%SIGNAL%" (timeout /t 1 >nul & goto LOOP) "
)

set REMAIN=15
:WARMUP
cls
echo ==========================================
echo   LAB MAINTENANCE v2.1 | PC: %PCID%
echo ==========================================
echo   STATUS: WARM-UP (%REMAIN%s)
echo   HW: K:%KBD_NAME% | M:%MSE_NAME%
echo   RAM: %MEM%MB | DISK: %DISK%GB
echo ==========================================
timeout /t 1 >nul
set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP

if exist "%SIGNAL%" del "%SIGNAL%"

:: ==================================================
:: [5] FINAL LOGS
:: ==================================================
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%F_MONTH%.txt"
set "RUN_COUNT=0"
if exist "%MONTHLYFILE%" (
    for /f "tokens=3" %%R in ('findstr /C:"Total Runs:" "%MONTHLYFILE%"') do set /a "RUN_COUNT=%%R"
)
set /a "RUN_COUNT+=1"

(
    echo Total Runs: %RUN_COUNT%
    echo Last Run: %F_DATE% %time%
) > "%MONTHLYFILE%"

echo [%date% %time%] SUCCESS >> "%LOGFILE%"
echo.
echo ========================================
echo   COMPLETE! Check Maintenance_Data folder.
echo ========================================
pause
