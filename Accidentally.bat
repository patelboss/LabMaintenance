@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Instant Exit Mode

:: ==================================================
:: [1] SETUP & SIGNAL
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "HEALTHDIR=%BASEDIR%\Health"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "LOGFILE=%BASEDIR%\log.txt"
set "SIGNAL=%temp%\maint_active.tmp"

if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if exist "%SIGNAL%" del "%SIGNAL%"
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
(echo PC ID: %PCID% & echo Date: %F_DATE% & echo Start: %time%) > "%HEALTHFILE%"

:: ==================================================
:: [4] START NATIVE WORKERS
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1
for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

:: ==================================================
:: [5] WARM-UP (INSTANT Q-EXIT)
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
echo   [!] PRESS 'Q' TO QUIT IMMEDIATELY
echo.

:: Choice acts as a 1-second timer. 
:: If Q is pressed, it jumps to ABORT instantly.
choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:: ==================================================
:: [6] COOLDOWN & FINALIZATION
:: ==================================================
:COOLDOWN_PHASE
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

:FINISH
color 07
(echo End: %time% & echo Status: SUCCESS) >> "%HEALTHFILE%"

echo.
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
    cls & color 0E
    echo [OK] Shutdown Aborted.
    timeout /t 10 >nul
    exit /b
)
exit /b

:: ==================================================
:: [7] THE INSTANT EXIT HANDLER
:: ==================================================
:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%"
cls & color 0C
echo [!] ABORT SIGNAL RECEIVED.
echo [!] Stopping CPU Workers and Exiting...
echo %date% %time% - User Aborted Cycle >> "%LOGFILE%"
timeout /t 2 /nobreak >nul
exit /b
