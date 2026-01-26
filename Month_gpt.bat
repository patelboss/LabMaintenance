@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Monthly Report Debug – Deep Logging (Win11 Safe)

echo ==================================================
echo   MONTHLY REPORT DEBUG SCRIPT
echo ==================================================
echo.

:: ==================================================
:: PATHS (same structure as main script)
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\monthly_debug.log"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "MONTHLYDIR=%BASEDIR%\Monthly"

echo [INFO] BASEDIR = %BASEDIR%

:: ==================================================
:: CREATE DIRECTORIES
:: ==================================================
if not exist "%BASEDIR%" (
    echo [ACTION] Creating BASEDIR
    mkdir "%BASEDIR%" || goto FAIL
)

if not exist "%MONTHLYDIR%" (
    echo [ACTION] Creating MONTHLYDIR
    mkdir "%MONTHLYDIR%" || goto FAIL
)

:: ==================================================
:: INIT LOG FILE
:: ==================================================
echo.>"%LOGFILE%" 2>nul
if not exist "%LOGFILE%" (
    echo [ERROR] Cannot create log file
    goto FAIL
)

echo ===== DEBUG START %date% %time% =====>>"%LOGFILE%"
echo [OK] Log file ready

:: ==================================================
:: PC ID CHECK
:: ==================================================
echo [STEP] Reading PC ID
if not exist "%PCIDFILE%" (
    echo [ERROR] pc_id.txt not found
    echo [ERROR] pc_id.txt missing>>"%LOGFILE%"
    goto FAIL
)

set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"

echo [INFO] PCID = %PCID%
echo PCID=%PCID%>>"%LOGFILE%"

:: ==================================================
:: DATE / MONTH KEYS (POWERSHELL ONLY)
:: ==================================================
echo [STEP] Getting date/time from PowerShell

for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format ddMMyyyyHHmm"') do set "TS=%%A"
for /f %%B in ('powershell -NoProfile -Command "Get-Date -Format MM-yyyy"') do set "MONTHKEY=%%B"

echo [DEBUG] TS=%TS%
echo [DEBUG] MONTHKEY=%MONTHKEY%

echo TS=%TS%>>"%LOGFILE%"
echo MONTHKEY=%MONTHKEY%>>"%LOGFILE%"

if not defined TS goto FAIL
if not defined MONTHKEY goto FAIL

:: ==================================================
:: MONTHLY FILE LOGIC
:: ==================================================
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%MONTHKEY%.txt"

echo [STEP] Monthly file = %MONTHLYFILE%
echo MonthlyFile=%MONTHLYFILE%>>"%LOGFILE%"

:: ==================================================
:: READ EXISTING RUN COUNT
:: ==================================================
set "RUN_COUNT=0"

if exist "%MONTHLYFILE%" (
    echo [INFO] Monthly file exists
    echo [INFO] Reading run count

    for /f "tokens=3 delims=:" %%R in ('findstr /C:"Total Runs:" "%MONTHLYFILE%"') do (
        set "RUN_COUNT=%%R"
    )

    set "RUN_COUNT=%RUN_COUNT: =%"
)

echo [INFO] Previous RUN_COUNT=%RUN_COUNT%
echo PrevRunCount=%RUN_COUNT%>>"%LOGFILE%"

:: ==================================================
:: INCREMENT RUN COUNT
:: ==================================================
set /a RUN_COUNT+=1

echo [INFO] New RUN_COUNT=%RUN_COUNT%
echo NewRunCount=%RUN_COUNT%>>"%LOGFILE%"

:: ==================================================
:: WRITE MONTHLY FILE
:: ==================================================
(
    echo ====================================
    echo MONTHLY SUMMARY
    echo ====================================
    echo PC ID      : %PCID%
    echo Month      : %MONTHKEY%
    echo Total Runs : %RUN_COUNT%
    echo Last Run   : %TS%
)>>"%MONTHLYFILE%"

if errorlevel 1 goto FAIL

echo [SUCCESS] Monthly report updated
echo SUCCESS>>"%LOGFILE%"

echo.
echo ==================================================
echo   DEBUG COMPLETED SUCCESSFULLY
echo ==================================================
pause
exit /b 0

:: ==================================================
:: FAIL HANDLER
:: ==================================================
:FAIL
echo.
echo **************************************************
echo   ERROR OCCURRED – SEE LOG BELOW
echo **************************************************
if exist "%LOGFILE%" type "%LOGFILE%"
pause
exit /b 1
