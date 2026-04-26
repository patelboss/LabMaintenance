@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – CPU Mode
:: configuration 
:: [L1] SIGNAL        : Temp file used to control/stop worker loops
:: [L2] NUMBER_OF_PROCESSORS : System CPU core count used for load calculation
:: [L3] LOAD          : Number of worker processes (~75%% of CPU cores)
:: [L4] LOGFILE       : CSV file path storing maintenance logs
:: [L5] REMAIN        : Total maintenance duration in seconds (1200 = 20 min)
:: [L6] LOGMOD        : Controls 60-sec logging interval using modulo
:: [L7] ELAPSED       : Time passed since start (used for 5-min trigger)
:: [L8] MOD           : Controls 5-minute popup interval using modulo
:: [L9] MINLEFT       : Remaining time converted to minutes for display
:: [L10] MSG          : Popup message content for maintenance status
:: ==================================================
:: [1] SIGNAL CONTROL
:: ==================================================
set "SIGNAL=%temp%\maint_active.tmp"

if exist "%SIGNAL%" del "%SIGNAL%"
echo active > "%SIGNAL%"
:: ==================================================
:: [2] START NOTIFICATION (FORCED)
:: ==================================================
start "" powershell -NoLogo -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Maintenance started. Contact admin for more information.')"

echo [INFO] Maintenance started. Contact admin if needed.

:: ==================================================
:: [3] CPU LOAD CALCULATION (~66%)
:: ==================================================
set /a LOAD=(%NUMBER_OF_PROCESSORS%*3)/4
if %LOAD% LSS 1 set LOAD=1

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c ^
    "for /L %%i in () do if not exist "%SIGNAL%" exit"
)

:: ==================================================
:: [5] LOG SETUP (CSV)
:: ==================================================
set "LOGFILE=%~dp0maintenance_log.csv"

if not exist "%LOGFILE%" (
    echo Timestamp,PCID,RemainingSeconds,Workers > "%LOGFILE%"
)
set "LIVEFILE=%~dp0maintenance_live.csv"

if exist "%LIVEFILE%" del "%LIVEFILE%"
echo Timestamp,PCID,RemainingSeconds,Workers > "%LIVEFILE%"
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
:: --- LIVE LOG (APPEND EVERY SECOND) ---
echo !DATE! !TIME!,%COMPUTERNAME%,!REMAIN!,%LOAD%>> "%LIVEFILE%"
:: --- INPUT CHECK ---
choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

:: --- COMMON CALCULATIONS ---
set /a LOGMOD=REMAIN %% 60
set /a ELAPSED=1200-REMAIN

:: --- LOG + 60-SEC HEARTBEAT ---
if !LOGMOD! EQU 0 (
    set /a MINLEFT=REMAIN/60
    echo !DATE! !TIME!,%COMPUTERNAME%,!REMAIN!,%LOAD%>> "%LOGFILE%"
    echo [LIVE] %COMPUTERNAME% ^| %LOAD% Workers ^| !MINLEFT!m left
)

:: --- 5-MIN POPUP WARNING ---
set /a MOD=ELAPSED %% 300
if !ELAPSED! NEQ 0 if !MOD! EQU 0 (
    set /a MINLEFT=REMAIN/60
    set "MSG=Maintenance running on %COMPUTERNAME% - !MINLEFT! min left"
    start "" powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('%MSG%','Maintenance')"
    echo msgbox "%MSG%",64,"Maintenance" > "%temp%\msg.vbs"
    cscript //nologo "%temp%\msg.vbs" >nul 2>&1
    del "%temp%\msg.vbs"
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

shutdown /s /t 60 /c "Maintenance Complete. will be SHUTDOWN after 1 minutes"

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
