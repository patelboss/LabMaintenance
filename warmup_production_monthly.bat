@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Native Monthly Production

:: ==================================================
:: PATHS & IDENTITY
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "MONTHLYDIR=%BASEDIR%\Health\Monthly"
set "SIGNAL=%temp%\maint_stop.tmp"

if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%"

:: Get PC ID (Ask once, remember forever)
if not exist "%PCIDFILE%" (
    set /p "USER_PCID=Enter ID for this PC: "
    echo !USER_PCID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"

echo ===== START %date% %time% ===== >> "%LOGFILE%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please Run as Administrator.
    pause & exit /b 1
)

:: ==================================================
:: START NATIVE LOAD (Independent Workers)
:: ==================================================
echo [STEP] Starting CPU Load...
echo go > "%SIGNAL%"
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

for /L %%A in (1,1,%LOAD%) do (
    start "Maint_Worker" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

:: ==================================================
:: WARM-UP LOOP (Visible UI)
:: ==================================================
set "REMAIN=20"
color 0B
:COUNTDOWN
cls
echo ==================================================
echo   MONTHLY MAINTENANCE: %PCID%
echo   Remaining Warm-up: !REMAIN! seconds
echo ==================================================
if !REMAIN! LEQ 0 goto FINISH
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto COUNTDOWN

:FINISH
color 07
if exist "%SIGNAL%" del "%SIGNAL%"

:: ==================================================
:: DISK SPACE CHECK (Native WMIC)
:: ==================================================
echo [STEP] Checking Disk Health...
for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value') do set "FREE_BYTES=%%D"
:: Convert Bytes to GB (Roughly)
set /a FREE_GB=%FREE_BYTES:~0,-6% / 1000 2>nul

:: ==================================================
:: MONTHLY REPORT (Reliable Date & Counter)
:: ==================================================
echo [STEP] Updating Monthly Report...

:: Get Year and Month safely (YYYY-MM)
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "dt=%%I"
set "STAMP=!dt:~0,4!-!dt:~4,2!"

set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%STAMP%.txt"

set "RUNS=0"
if exist "%MONTHLYFILE%" (
    for /f "tokens=3" %%R in ('findstr /C:"Total Runs:" "%MONTHLYFILE%"') do set "RUNS=%%R"
)
set /a RUNS+=1

(
    echo PC ID: %PCID%
    echo Month: %STAMP%
    echo Total Runs: %RUNS%
    echo Last Run: %date% %time%
    echo Free Space (C:): %FREE_GB% GB
)> "%MONTHLYFILE%"

echo [OK] Report updated. Free Space: %FREE_GB% GB. >> "%LOGFILE%"

:: ==================================================
:: SHUTDOWN
:: ==================================================
echo [STEP] Maintenance complete. Shutting down in 60s...
shutdown /s /t 60 /c "Monthly Maintenance on %PCID% complete."
echo ===== END %date% %time% ===== >> "%LOGFILE%"
exit /b 0
