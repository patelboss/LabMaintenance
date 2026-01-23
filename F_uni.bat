@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Universal Edition

:: ==================================================
:: [1] PATHS & AUTO-SETUP
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "LOGFILE=%BASEDIR%\log.txt"
set "SIGNAL=%temp%\maint_active.tmp"

if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1
if exist "%SIGNAL%" del "%SIGNAL%"

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
:: Get Clean Date
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "dt=%%I"
set "F_DATE=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!"
set "F_MONTH=!dt:~0,4!-!dt:~4,2!"
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_!time:~0,2!!time:~3,2!.txt"
set "HEALTHFILE=%HEALTHFILE: =0%"

(echo PC ID: %PCID% & echo Date: %F_DATE% & echo Start: %time%) > "%HEALTHFILE%"

:: ==================================================
:: [4] START BACKGROUND WORKERS (LATEST WINDOWS FIX)
:: ==================================================
:: We use 'start /b' to run workers in the SAME window but in background.
:: This prevents Windows 11 Terminal from opening multiple tabs/windows.
echo active > "%SIGNAL%"
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

for /L %%A in (1,1,%LOAD%) do (
    start /b cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

:: ==================================================
:: [5] WARM-UP (INSTANT EXIT)
:: ==================================================
set "REMAIN=20"
color 0B
:WARMUP_LOOP
cls
echo ==================================================
echo   WARM-UP: %PCID% (Latest Windows Build)
echo ==================================================
echo   TIME REMAINING: %REMAIN%s
echo   LOAD: %LOAD% Workers Active
echo ==================================================
echo   [!] PRESS 'Q' TO STOP SAFELY
echo.

:: Latest Windows choice fix: Wait 1 sec
choice /c qn /t 1 /d n /n >nul 2>&1
if !errorlevel! equ 1 goto GRACEFUL_ABORT

set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP_LOOP

:: ==================================================
:: [6] COOLDOWN & FINALIZATION
:: ==================================================
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

:: Write Reports
(echo End: %time% & echo Status: SUCCESS) >> "%HEALTHFILE%"

:: Monthly Logic
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%F_MONTH%.txt"
set "RUN_COUNT=0"
if exist "%MONTHLYFILE%" (
    for /f "tokens=3" %%R in ('findstr /C:"Total Runs:" "%MONTHLYFILE%"') do set /a "RUN_COUNT=%%R"
)
set /a "RUN_COUNT+=1"
(echo Total Runs: %RUN_COUNT% & echo Last Run: %F_DATE%) > "%MONTHLYFILE%"

:: ==================================================
:: [7] SHUTDOWN CANCEL
:: ==================================================
color 07
echo [OK] All logs updated.
shutdown /s /t 60 /c "Maintenance Complete."
echo PRESS 'C' TO CANCEL SHUTDOWN...

choice /c c /t 60 /d c /n >nul 2>&1
if !errorlevel! equ 1 (
    shutdown /a >nul 2>&1
    cls & color 0E & echo [OK] Shutdown Cancelled.
    timeout /t 5 >nul
    exit /b
)
exit /b

:GRACEFUL_ABORT
if exist "%SIGNAL%" del "%SIGNAL%"
cls & color 0C
echo [!] ABORTED. Workers Stopped.
timeout /t 3 >nul
exit /b

