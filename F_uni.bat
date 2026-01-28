@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance Master – v1.0 [Win11 Native]

:: ==================================================
:: [1] DIRECTORY & PATH SETUP
:: ==================================================
set "BASEDIR=C:\Lab_Maintenance"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "LOGFILE=%BASEDIR%\master_log.log"
set "SIGNAL=%temp%\maint_active.tmp"

:: Ensure directories exist
if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1

:: Clean up signal files
if exist "%SIGNAL%" del "%SIGNAL%" >nul 2>&1

:: ==================================================
:: [2] IDENTITY & ADMIN VERIFICATION
:: ==================================================
net session >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] PLEASE RIGHT-CLICK AND 'RUN AS ADMINISTRATOR'
    pause & exit /b
)

if not exist "%PCIDFILE%" (
    cls
    echo ==================================================
    echo          FIRST-RUN SETUP: IDENTITY
    echo ==================================================
    set /p "NEW_ID=Enter PC ID (e.g., PC-01): "
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"

:: ==================================================
:: [3] DATA COLLECTION (WINDOWS 11 NATIVE)
:: ==================================================
echo [STEP 1] Fetching Time and Date...
for /f "tokens=1,2" %%A in ('powershell -NoProfile -Command "Get-Date -Format 'ddMMyyyyHHmm MM-yyyy'"') do (
    set "TS=%%A"
    set "MONTHKEY=%%B"
)

echo [STEP 2] Fetching System Health...
for /f %%M in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)"') do set "RAM=%%M"
for /f %%D in ('powershell -NoProfile -Command "$d=(Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:'); if($d){ [math]::Round($d.FreeSpace / 1GB) } else { 0 }"') do set "DISK=%%D"

echo [STEP 3] Auditing USB Peripherals...
for /f "delims=" %%K in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD_NAME=%%K"
if defined KBD_NAME (set "KBD_STATUS=OK") else (set "KBD_STATUS=MISSING" & set "KBD_NAME=None")

for /f "delims=" %%M in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE_NAME=%%M"
if defined MSE_NAME (set "MSE_STATUS=OK") else (set "MSE_STATUS=MISSING" & set "MSE_NAME=None")

:: --- CREATE INITIAL HEALTH FILE ---
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%TS%.txt"
(
    echo PC AUDIT REPORT
    echo ------------------
    echo ID        : %PCID%
    echo Time      : %TS%
    echo [SYSTEM]
    echo RAM FREE  : %RAM% MB
    echo DISK FREE : %DISK% GB
    echo [HARDWARE]
    echo KEYBOARD  : %KBD_STATUS% [%KBD_NAME%]
    echo MOUSE     : %MSE_STATUS% [%MSE_NAME%]
    echo ------------------
    echo Start Time: %time%
) > "%HEALTHFILE%"

:: ==================================================
:: [4] WARM-UP (LOAD TEST)
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1
echo active > "%SIGNAL%"

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

set "REMAIN=20"
color 0B
:WARMUP_LOOP
cls
echo ==================================================
echo   PC: %PCID%  |  STATUS: WARM-UP (%REMAIN%s)
echo ==================================================
echo   KBD: %KBD_STATUS% (%KBD_NAME%)
echo   MSE: %MSE_STATUS% (%MSE_NAME%)
echo   RAM: %RAM% MB | DISK: %DISK% GB
echo ==================================================
echo.
echo   [!] PRESS 'Q' TO QUIT IMMEDIATELY
echo.

choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:: ==================================================
:: [5] COOLDOWN & FINALIZATION
:: ==================================================
:COOLDOWN_PHASE
if exist "%SIGNAL%" del "%SIGNAL%" >nul 2>&1
set "CD=20"
color 0A
:CD_LOOP
cls
echo ==================================================
echo   PC: %PCID%  |  STATUS: COOLDOWN (%CD%s)
echo ==================================================
echo   STABILIZING HARDWARE...
echo ==================================================
timeout /t 1 /nobreak >nul
set /a CD-=1
if %CD% GTR 0 goto CD_LOOP

:: Finalize Health File
(echo End Time: %time% & echo Status: SUCCESS) >> "%HEALTHFILE%"

:: ==================================================
:: [6] UPDATING MONTHLY REPORT (DEEP LOGGING)
:: ==================================================
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%MONTHKEY%.txt"
set "RUN_COUNT=0"

if exist "%MONTHLYFILE%" (
    for /f "tokens=3 delims=:" %%R in ('findstr /C:"Total Runs:" "%MONTHLYFILE%"') do (
        set "VAL=%%R"
        set "VAL=!VAL: =!"
        set "RUN_COUNT=!VAL!"
    )
)

set /a RUN_COUNT+=1

(
    echo ====================================
    echo MONTHLY SUMMARY
    echo ====================================
    echo PC ID      : %PCID%
    echo Month      : %MONTHKEY%
    echo Total Runs : %RUN_COUNT%
    echo Last Run   : %TS%
    echo Last Audit : RAM:%RAM%MB DISK:%DISK%GB
)> "%MONTHLYFILE%"

:: ==================================================
:: [7] SMART SHUTDOWN
:: ==================================================
color 07
cls
echo ==================================================
echo   MAINTENANCE COMPLETE - %PCID%
echo ==================================================
echo   System will shutdown in 60 seconds.
echo   PRESS 'C' TO CANCEL AND STAY ON PC.
echo ==================================================

shutdown /s /t 60 /c "Maintenance on %PCID% complete."

choice /c c /t 60 /d c /n >nul 2>&1
if !errorlevel! equ 1 (
    shutdown /a >nul 2>&1
    cls & color 0E
    echo [OK] Shutdown Aborted.
    echo Script finished.
    timeout /t 10 >nul
    exit /b
)
exit /b

:: ==================================================
:: [8] INSTANT ABORT HANDLER
:: ==================================================
:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%" >nul 2>&1
cls & color 0C
echo [!] ABORT SIGNAL RECEIVED.
echo [!] Stopping CPU Workers and Exiting...
echo %date% %time% - User Aborted Cycle: %PCID% >> "%LOGFILE%"
timeout /t 2 /nobreak >nul
exit /b
