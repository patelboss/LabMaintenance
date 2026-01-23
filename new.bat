@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – CORE STABLE v1.0

:: ==================================================
:: [1] DIRECTORY SETUP
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_signal.tmp"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1

:: ==================================================
:: [2] IDENTITY (Runs only once)
:: ==================================================
if not exist "%PCIDFILE%" (
    cls
    echo [SETUP] No PC ID found.
    set /p "NEW_ID=Enter PC ID: "
    echo !NEW_ID! > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"

:: ==================================================
:: [3] LOGGING START (The "Black Box")
:: ==================================================
echo [%date% %time%] --- SCRIPT START: %PCID% --- >> "%LOGFILE%"
echo [%date% %time%] STEP: Admin Check >> "%LOGFILE%"

net session >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] Admin Rights Required.
    echo [%date% %time%] FAIL: Admin Check >> "%LOGFILE%"
    pause & exit /b 1
)
echo [%date% %time%] OK: Admin Confirmed >> "%LOGFILE%"

:: ==================================================
:: [4] PRE-RUN DATA (Date/RAM/Temp)
:: ==================================================
echo [%date% %time%] STEP: Gathering Pre-Run Data >> "%LOGFILE%"

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%I"
set "F_DATE=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!"
set "F_MONTH=!dt:~0,4!-!dt:~4,2!"

set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%F_DATE%_!time:~0,2!!time:~3,2!.txt"
set "HEALTHFILE=%HEALTHFILE: =0%"

set "MEM=Unknown"
for /f "tokens=2 delims==" %%M in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (set /a "MEM=%%M / 1024")

(
    echo PC ID: %PCID%
    echo Start Time: %time%
    echo RAM Available: %MEM% MB
    echo ---
)> "%HEALTHFILE%"

:: ==================================================
:: [5] WARM-UP (Using your stable Timeout logic)
:: ==================================================
echo [%date% %time%] STEP: Starting Warm-up >> "%LOGFILE%"
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

echo active > "%SIGNAL%"
for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c "for /L %%i in () do (if not exist "%SIGNAL%" exit)"
)

set REMAIN=20
color 0B
:WARMUP_LOOP
cls
echo [PC: %PCID%] [MODE: WARM-UP]
echo Time Remaining: %REMAIN% sec
if %REMAIN% LEQ 0 goto WARMUP_DONE
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto WARMUP_LOOP

:WARMUP_DONE
if exist "%SIGNAL%" del "%SIGNAL%"
echo [%date% %time%] OK: Warm-up Finished >> "%LOGFILE%"

:: ==================================================
:: [6] COOLDOWN & FINAL REPORT
:: ==================================================
set CD=20
color 0A
:COOLDOWN_LOOP
cls
echo [PC: %PCID%] [MODE: COOLDOWN]
echo Time Remaining: %CD% sec
if %CD% LEQ 0 goto COOLDOWN_DONE
timeout /t 1 /nobreak >nul
set /a CD-=1
goto COOLDOWN_LOOP

:COOLDOWN_DONE
echo [%date% %time%] STEP: Generating Final Reports >> "%LOGFILE%"
color 07
set "END_TIME=%time%"

(echo End Time: %END_TIME% & echo Status: SUCCESS)>>"%HEALTHFILE%"

:: Monthly Summary
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%F_MONTH%.txt"
set "RUN_COUNT=0"
if exist "%MONTHLYFILE%" (
    for /f "tokens=3" %%R in ('findstr /C:"Total Runs:" "%MONTHLYFILE%"') do set /a "RUN_COUNT=%%R"
)
set /a "RUN_COUNT+=1"
(echo Total Runs: %RUN_COUNT% & echo Last Run: %F_DATE% at %END_TIME%)> "%MONTHLYFILE%"

:: ==================================================
:: [7] SHUTDOWN
:: ==================================================
echo [%date% %time%] STEP: Triggering Shutdown >> "%LOGFILE%"
shutdown /s /t 120 /c "Maintenance on %PCID% complete."
echo.
echo [COMPLETE] Press any key to cancel shutdown.
pause >nul
shutdown /a >nul 2>&1
echo [%date% %time%] --- SCRIPT END (User Cancelled Shutdown) --- >> "%LOGFILE%"
exit /b

