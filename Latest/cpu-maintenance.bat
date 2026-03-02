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
:: [2] VERIFY ADMIN
:: ==================================================
net session >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] Run as Administrator.
    pause
    exit /b
)

:: ==================================================
:: [3] START CPU WORKERS
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c ^
    "for /L %%i in () do if not exist "%SIGNAL%" exit"
)

:: ==================================================
:: [4] WARM-UP TIMER (INSTANT Q EXIT)
:: ==================================================
set "REMAIN=20"
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

choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:: ==================================================
:: [5] COOLDOWN
:: ==================================================
:COOLDOWN
if exist "%SIGNAL%" del "%SIGNAL%"
set "CD=20"
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
:: [6] FINISH & SHUTDOWN PROMPT
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

choice /c c /t 60 /d c /n >nul 2>&1
if !errorlevel! equ 1 (
    shutdown /a >nul 2>&1
    cls
    color 0E
    echo [OK] Shutdown Aborted.
    timeout /t 10 >nul
)

exit /b

:: ==================================================
:: [7] ABORT HANDLER
:: ==================================================
:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%"
cls
color 0C
echo [!] ABORT SIGNAL RECEIVED.
echo [!] Stopping CPU Workers...
timeout /t 2 /nobreak >nul
exit /b
