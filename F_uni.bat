@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance Master – v1.3 [CPU Fix]

:: ==================================================
:: [1] DIRECTORY & PATH SETUP
:: ==================================================
set "BASEDIR=C:\Lab_Maintenance"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "LOGFILE=%BASEDIR%\master_log.log"
set "SIGNAL=%temp%\maint_active.txt"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1

:: Ensure a fresh signal file
echo active > "%SIGNAL%"

:: ==================================================
:: [2] IDENTITY & ADMIN VERIFICATION
:: ==================================================
net session >nul 2>&1 || (color 0C & echo [ERROR] Run as Admin & pause & exit /b)

if not exist "%PCIDFILE%" (
    set /p "NEW_ID=Enter PC ID: "
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"

:: ==================================================
:: [3] DATA COLLECTION (WIN11 NATIVE)
:: ==================================================
echo [STEP] Gathering Health Data...
for /f "tokens=1,2" %%A in ('powershell -NoProfile -Command "Get-Date -Format 'ddMMyyyyHHmm MM-yyyy'"') do (
    set "TS=%%A"
    set "MONTHKEY=%%B"
)
for /f %%M in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)"') do set "RAM=%%M"
for /f %%D in ('powershell -NoProfile -Command "$d=(Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:'); if($d){ [math]::Round($d.FreeSpace / 1GB) } else { 0 }"') do set "DISK=%%D"

:: Peripheral Audit
for /f "delims=" %%K in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD_NAME=%%K"
if defined KBD_NAME (set "KBD_STATUS=OK") else (set "KBD_STATUS=MISSING" & set "KBD_NAME=None")
for /f "delims=" %%M in ('powershell -NoProfile -Command "Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE_NAME=%%M"
if defined MSE_NAME (set "MSE_STATUS=OK") else (set "MSE_STATUS=MISSING" & set "MSE_NAME=None")

set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%TS%.txt"
(
    echo ID: %PCID% ^| Time: %TS%
    echo RAM: %RAM% MB ^| Disk: %DISK% GB
    echo KBD: %KBD_STATUS% [%KBD_NAME%] ^| MSE: %MSE_STATUS% [%MSE_NAME%]
) > "%HEALTHFILE%"

:: ==================================================
:: [4] WARM-UP (STABLE CPU LOAD)
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%
echo [%time%] Starting %LOAD% workers >> "%LOGFILE%"

:: Workers check for the signal file every 2 seconds to reduce I/O lag
for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c "title MAINT_WORKER & :LOOP & timeout /t 2 >nul & if exist %SIGNAL% goto LOOP"
)

set "REMAIN=20"
color 0B
:WARMUP_LOOP
cls
echo ==================================================
echo   PC: %PCID%  ^|  WARM-UP: %REMAIN%s
echo ==================================================
echo   KBD: %KBD_STATUS% ^| MSE: %MSE_STATUS%
echo   CPU LOAD: %LOAD% THREADS ACTIVE
echo ==================================================
echo.
echo   [!] PRESS 'Q' TO ABORT
echo.

choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:: ==================================================
:: [5] COOLDOWN (FORCE KILL WORKERS)
:: ==================================================
:COOLDOWN_PHASE
if exist "%SIGNAL%" del "%SIGNAL%" /f /q >nul 2>&1
:: Kill any surviving workers by window title to be 100% sure
taskkill /fi "windowtitle eq MAINT_WORKER*" /f >nul 2>&1

set "CD=15"
color 0A
:CD_LOOP
cls
echo ==================================================
echo   PC: %PCID%  ^|  COOLDOWN: %CD%s
echo ==================================================
echo   WORKERS KILLED. STABILIZING...
echo ==================================================
timeout /t 1 /nobreak >nul
set /a CD-=1
if %CD% GTR 0 goto CD_LOOP

:: Finalize
(echo End: %time% ^| Status: SUCCESS) >> "%HEALTHFILE%"

:: ==================================================
:: [6] MONTHLY REPORT
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
    echo Total Runs : %RUN_COUNT%
    echo Last Run   : %TS%
    echo PC ID      : %PCID%
)> "%MONTHLYFILE%"

:: ==================================================
:: [7] SHUTDOWN
:: ==================================================
color 07
cls
echo Maintenance complete. Shutdown in 60s. 'C' to cancel.
shutdown /s /t 60 /c "Maintenance Complete"
choice /c c /t 60 /d c /n >nul 2>&1
if !errorlevel! equ 1 (shutdown /a >nul 2>&1 & echo Aborted. & timeout /t 5 >nul)
exit /b

:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%" /f /q >nul 2>&1
taskkill /fi "windowtitle eq MAINT_WORKER*" /f >nul 2>&1
cls & color 0C
echo [!] ABORTED. Workers stopped.
timeout /t 3 >nul
exit /b
