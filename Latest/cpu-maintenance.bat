@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – CPU Mode

:: ==================================================
:: [1] SIGNAL CONTROL
:: ==================================================
set "SIGNAL=%temp%\maint_active.tmp"

if exist "%SIGNAL%" del "%SIGNAL%"
echo active > "%SIGNAL%"

:: ==================================================
:: [2] START NOTIFICATION (FORCED)
:: ==================================================
msg * "Maintenance started. Contact admin for more information."
echo [INFO] Maintenance started. Contact admin if needed.

:: ==================================================
:: [3] CPU LOAD CALCULATION (~66%)
:: ==================================================
set /a LOAD=(%NUMBER_OF_PROCESSORS%*2)/3
if %LOAD% LSS 1 set LOAD=1

:: ==================================================
:: [4] START CPU WORKERS (REAL WORKLOAD)
:: ==================================================
for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c ^
    "setlocal EnableDelayedExpansion ^
    set /a x=1 ^
    for /L %%i in () do ( ^
        if not exist "%SIGNAL%" exit ^
        set /a x=(x*1103515245+12345) %% 2147483647 ^
    )"
)

:: ==================================================
:: [5] LOG SETUP (CSV)
:: ==================================================
set "LOGFILE=%~dp0maintenance_log.csv"

if not exist "%LOGFILE%" (
    echo Timestamp,PCID,RemainingSeconds,Workers > "%LOGFILE%"
)

:: ==================================================
:: [6] MAIN TIMER (INSTANT Q EXIT)
:: ==================================================
set "REMAIN=1200"
color 0B

:WARMUP_LOOP
cls
echo ==================================================
echo   CPU MAINTENANCE ACTIVE
echo   STATUS: STRESSING HARDWARE (%LOAD% Workers)
echo ==================================================
echo   TIME REMAINING: %REMAIN%s
echo.
echo   [!] PRESS 'Q' TO QUIT IMMEDIATELY
echo ==================================================

:: --- INPUT CHECK ---
choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

:: --- LOG EVERY 60 SECONDS ---
set /a LOGMOD=REMAIN %% 60
if !LOGMOD! EQU 0 (
    echo %DATE% %TIME%,%COMPUTERNAME%,!REMAIN!,%LOAD%>> "%LOGFILE%"
)

:: --- 5-MIN HEARTBEAT STATUS ---
set /a ELAPSED=1200-REMAIN
if !ELAPSED! NEQ 0 (
    set /a MOD=ELAPSED %% 300
    if !MOD! EQU 0 (

        set /a MINLEFT=REMAIN/60

        echo ==================================================
        echo [HEARTBEAT] MAINTENANCE ACTIVE
        echo Status      : Running
        echo Load Target : %LOAD% Workers (~66%% CPU)
        echo Time Left   : !MINLEFT! minutes
        echo Machine     : %COMPUTERNAME%
        echo ==================================================
    )
)

:: --- TIMER ---
set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:: ==================================================
:: [7] COOLDOWN
:: ==================================================
:COOLDOWN
if exist "%SIGNAL%" del "%SIGNAL%"
set "CD=600"
color 0A

:CD_LOOP
cls
echo ==================================================
echo   COOLDOWN: %CD%s REMAINING
echo ==================================================
timeout /t 1 /nobreak >nul
set /a CD-=1
if %CD% GTR 0 goto CD_LOOP

:: ==================================================
:: [8] FINISH & SHUTDOWN PROMPT
:: ==================================================
color 07
cls
echo ==================================================
echo   MAINTENANCE COMPLETE
echo ==================================================
echo   System will shutdown in 60 seconds.
echo   PRESS 'C' TO CANCEL AND STAY ON PC.
echo ==================================================

shutdown /s /t 60 /c "Maintenance Complete."

choice /c cn /t 60 /d n /n >nul 2>&1
if !errorlevel! equ 1 (
    shutdown /a >nul 2>&1
    cls
    color 0E
    echo [OK] Shutdown Aborted.
    timeout /t 10 >nul
)

exit /b

:: ==================================================
:: [9] ABORT HANDLER
:: ==================================================
:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%"
cls
color 0C
echo [!] ABORT SIGNAL RECEIVED.
echo [!] Stopping CPU Workers...
timeout /t 2 /nobreak >nul
exit /b
