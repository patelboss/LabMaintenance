@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Ultra Stable Mode

:: ==================================================
:: [1] AUTO-SETUP & SIGNAL
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "HEALTHDIR=%BASEDIR%\Health"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "SIGNAL=%temp%\maint_active.tmp"

if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1

:: Create signal for workers
echo active > "%SIGNAL%"

:: ==================================================
:: [2] IDENTITY & ADMIN
:: ==================================================
if not exist "%PCIDFILE%" (
    set /p "NEW_ID=Enter PC ID: "
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"

net session >nul 2>&1
if errorlevel 1 (
    color 0C & echo [ERROR] Run as Administrator. & pause & exit /b
)

:: ==================================================
:: [3] PRE-RUN HEALTH DATA
:: ==================================================
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "dt=%%I"
set "F_DATE=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!"
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_!time:~0,2!!time:~3,2!.txt"
set "HEALTHFILE=%HEALTHFILE: =0%"

(echo PC ID: %PCID% & echo Date: %F_DATE% & echo Start: %time% & echo ---) > "%HEALTHFILE%"

:: ==================================================
:: [4] START NATIVE WORKERS
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

:: ==================================================
:: [5] WARM-UP WITH ACCIDENT PREVENTION
:: ==================================================
set "REMAIN=20"
color 0B

:WARMUP_LOOP
cls
echo ==================================================
echo   WARM-UP IN PROGRESS: %PCID%
echo   STATUS: STRESSING HARDWARE (%LOAD% Workers)
echo ==================================================
echo   TIME REMAINING: %REMAIN%s
echo.
echo   [!] Press 'Q' to CANCEL Safely.
echo   (All other keys are ignored)

:: 'choice' acts as our filter. It waits 1 second for 'Q'. 
:: Any other key (except Ctrl+C) is simply ignored.
choice /c qn /t 1 /d n /n >nul 2>&1

if !errorlevel! equ 1 (
    :: Q was pressed - Double Check Confirmation
    cls & color 0E
    echo ==================================================
    echo          CONFIRM SAFE EXIT?
    echo ==================================================
    echo   You pressed 'Q'. Do you want to stop?
    echo.
    echo   [Y] Yes, Stop and Exit Safely
    echo   [N] No, Continue Warm-up
    echo.
    echo   (Resuming in 5 seconds if no key pressed...)
    
    choice /c yn /t 5 /d n /n >nul 2>&1
    if !errorlevel! equ 1 goto GRACEFUL_ABORT
    color 0B
)

set /a REMAIN-=1
if %REMAIN% LEQ 0 goto COOLDOWN_PHASE
goto WARMUP_LOOP

:: ==================================================
:: [6] COOLDOWN & FINALIZATION
:: ==================================================
:COOLDOWN_PHASE
if exist "%SIGNAL%" del "%SIGNAL%"
set "CD=20"
color 0A
:CD_LOOP
cls
echo [COOLDOWN] Stabilizing Thermal Levels: %CD%s
if %CD% LEQ 0 goto FINISH
timeout /t 1 /nobreak >nul
set /a CD-=1 & goto CD_LOOP

:FINISH
color 07
(echo End: %time% & echo Status: SUCCESS) >> "%HEALTHFILE%"

:: ==================================================
:: [7] SMART SHUTDOWN WITH CANCEL OPTION
:: ==================================================
echo.
echo ==================================================
echo   MAINTENANCE COMPLETE
echo ==================================================
echo   System will shutdown in 60 seconds.
echo   PRESS ANY KEY TO CANCEL SHUTDOWN AND STAY ON PC.
echo ==================================================

shutdown /s /t 60 /c "Maintenance Complete. Press any key in the script window to stay on."

:: Wait 60s for a key. If pressed, errorlevel is 1.
choice /t 60 /d y /n /m ">" >nul 2>&1

if %errorlevel% equ 1 (
    shutdown /a >nul 2>&1
    cls & color 0E
    echo [OK] Shutdown Aborted. You may now use the PC.
    timeout /t 10 >nul
    exit /b
)
exit /b

:: ==================================================
:: [8] THE SAFE EXIT HANDLER
:: ==================================================
:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%"
cls & color 0C
echo [!] ABORTING... CPU Workers Stopped.
echo [!] Maintenance Logged as 'USER ABORTED'.
echo %date% %time% - User Aborted Cycle >> "%BASEDIR%\log.txt"
timeout /t 3 >nul
exit /b

