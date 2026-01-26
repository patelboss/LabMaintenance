:: ---------- RAM (SAFE) ----------
set "MEM_MB=0"

for /f "tokens=2 delims==" %%M in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (
    if not "%%M"=="" set "MEM_RAW=%%M"
)

if defined MEM_RAW (
    set /a MEM_MB=MEM_RAW / 1024 2>nul
)

if "%MEM_MB%"=="0" (
    set "MEM_MB=Not Available"
)



@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Master Production v2.0 (Windows 11 Safe)

echo ==================================================
echo   LAB MAINTENANCE SCRIPT STARTED
echo ==================================================
echo.

:: ==================================================
:: PATHS
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_active.tmp"

mkdir "%BASEDIR%"  >nul 2>&1
mkdir "%HEALTHDIR%" >nul 2>&1
mkdir "%MONTHLYDIR%">nul 2>&1

echo [%date% %time%] Script started>>"%LOGFILE%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [CHECK] Administrator rights...
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Run this script as Administrator
    echo [ERROR] Run as Administrator>>"%LOGFILE%"
    pause
    goto END
)
echo [OK] Administrator confirmed
echo [OK] Administrator confirmed>>"%LOGFILE%"

:: ==================================================
:: PC ID
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [SETUP] Enter PC ID:
    set /p PCID=
    echo %PCID%>"%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"
echo [INFO] PC ID = %PCID%
echo [INFO] PC ID = %PCID%>>"%LOGFILE%"

:: ==================================================
:: DATE / TIME (POWERSHELL – SAFE)
:: ==================================================
for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format ddMMyyyyHHmm"') do set "TS=%%A"
for /f %%B in ('powershell -NoProfile -Command "Get-Date -Format MM-yyyy"') do set "MONTHKEY=%%B"

echo [INFO] Timestamp = %TS%
echo [INFO] Timestamp = %TS%>>"%LOGFILE%"

:: ==================================================
:: HEALTH COLLECTION
:: ==================================================
echo [STEP] Collecting system health...
echo [STEP] Collecting system health>>"%LOGFILE%"

:: RAM
for /f %%R in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024 -as [int]"') do set "RAM=%%R"
echo [DATA] Free RAM = %RAM% MB

:: CPU TEMP (best effort)
for /f %%T in ('powershell -NoProfile -Command "$t=Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue;if($t){[int](($t.CurrentTemperature/10)-273)}else{'N/A'}"') do set "TEMP=%%T"
echo [DATA] CPU Temp = %TEMP%

:: DISK SPACE
for /f %%D in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace/1GB)"') do set "DISK=%%D"
echo [DATA] Free Disk C: = %DISK% GB

:: HEALTH FILE
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%TS%.txt"

(
echo PC ID            : %PCID%
echo Timestamp        : %TS%
echo Free RAM (MB)    : %RAM%
echo CPU Temp (C)     : %TEMP%
echo Free Disk (GB)   : %DISK%
echo Status           : SUCCESS
)> "%HEALTHFILE%"

if not exist "%HEALTHFILE%" (
    echo [ERROR] Health report not created
    pause
    goto END
)

echo [OK] Health report created
echo [OK] Health report created>>"%LOGFILE%"

:: ==================================================
:: CPU WARM-UP
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

echo active>"%SIGNAL%"
echo [STEP] Starting CPU warm-up (%LOAD% workers)
echo [STEP] Starting CPU warm-up>>"%LOGFILE%"

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_CPU" /min cmd /c "for /L %%i in () do if not exist "%SIGNAL%" exit"
)

set REMAIN=20
:WARMUP
echo Warm-up remaining: %REMAIN%s
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP

del "%SIGNAL%"

:: ==================================================
:: MONTHLY REPORT
:: ==================================================
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%MONTHKEY%.txt"

if not exist "%MONTHLYFILE%" (
    echo Monthly Report (%MONTHKEY%)>"%MONTHLYFILE%"
    echo PC ID: %PCID%>>"%MONTHLYFILE%"
    echo -------------------------->>"%MONTHLYFILE%"
)

echo %TS% | RAM:%RAM%MB | DISK:%DISK%GB | OK>>"%MONTHLYFILE%"

echo [OK] Monthly report updated
echo [OK] Monthly report updated>>"%LOGFILE%"

:: ==================================================
:: SHUTDOWN
:: ==================================================
echo.
echo MAINTENANCE COMPLETE
echo System will shutdown in 60 seconds
shutdown /s /t 60 /c "Maintenance complete on %PCID%"
pause
shutdown /a

:END
echo Script finished.
pause
exit /b
