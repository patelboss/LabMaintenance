@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production (DEBUG)

:: ==================================================
:: SIMPLE LOG FUNCTION (INLINE)
:: ==================================================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt

if not exist "%BASEDIR%" mkdir "%BASEDIR%"

echo. >> "%LOGFILE%"
echo ===== SCRIPT STARTED %date% %time% ===== >> "%LOGFILE%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [STEP] Checking admin rights >> "%LOGFILE%"
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Not running as admin >> "%LOGFILE%"
    echo ERROR: Run as Administrator.
    pause
    exit /b 1
)
echo [OK] Admin check passed >> "%LOGFILE%"

:: ==================================================
:: CONFIGURATION
:: ==================================================
set WARMUP_MINUTES=30
set SHUTDOWN_WARNING_SECONDS=120

echo [CONFIG] Warmup=%WARMUP_MINUTES% min, Shutdown=%SHUTDOWN_WARNING_SECONDS% sec >> "%LOGFILE%"

:: ==================================================
:: PATHS
:: ==================================================
set CPULOADER=%BASEDIR%\cpu_load.cmd
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health
set MONTHLYDIR=%HEALTHDIR%\Monthly

if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%"

echo [OK] Paths verified >> "%LOGFILE%"

:: ==================================================
:: WRITE MODE CHECK
:: ==================================================
echo [STEP] Checking write capability >> "%LOGFILE%"
set WRITE_MODE=0
echo test > "%BASEDIR%\.__write_test.tmp" 2>nul

if exist "%BASEDIR%\.__write_test.tmp" (
    del "%BASEDIR%\.__write_test.tmp" >nul 2>&1
    set WRITE_MODE=1
    echo [MODE] WRITE MODE >> "%LOGFILE%"
) else (
    echo [MODE] READ-ONLY MODE >> "%LOGFILE%"
)

:: ==================================================
:: PC ID
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [ERROR] pc_id.txt missing >> "%LOGFILE%"
    exit /b 1
)
set /p PCID=<"%PCIDFILE%"
echo [INFO] PC ID = %PCID% >> "%LOGFILE%"

:: ==================================================
:: DATE / TIME SAFE
:: ==================================================
for /f %%A in ('wmic os get localdatetime ^| find "."') do set DTS=%%A
set CURRDATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
set CURRTIME=%DTS:~8,2%:%DTS:~10,2%

echo [INFO] Date=%CURRDATE% Time=%CURRTIME% >> "%LOGFILE%"

set HEALTHFILE=%HEALTHDIR%\Health_%CURRDATE%_%PCID%.txt
set MONTHLYFILE=%MONTHLYDIR%\Monthly_%CURRDATE:~0,7%_%PCID%.txt

:: ==================================================
:: CPU LOAD CALCULATION
:: ==================================================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

echo [INFO] CPU Cores=%CORES%, Load Threads=%LOAD% >> "%LOGFILE%"

:: ==================================================
:: HEALTH FILE HEADER
:: ==================================================
if "%WRITE_MODE%"=="1" (
    echo PC ID: %PCID% > "%HEALTHFILE%"
    echo Date: %CURRDATE% >> "%HEALTHFILE%"
    echo Start Time: %CURRTIME% >> "%HEALTHFILE%"
    echo CPU Cores: %CORES% >> "%HEALTHFILE%"
    echo Load Threads: %LOAD% >> "%HEALTHFILE%"
    echo [OK] Health file created >> "%LOGFILE%"
)

:: ==================================================
:: START CPU LOAD
:: ==================================================
echo [STEP] Starting CPU load >> "%LOGFILE%"
for /L %%A in (1,1,%LOAD%) do (
    start "" /B "%CPULOADER%"
)
echo [OK] CPU load running >> "%LOGFILE%"

:: ==================================================
:: WARMUP COUNTDOWN (FIXED)
:: ==================================================
set REMAIN=%WARMUP_MINUTES%
color 0B
echo [STEP] Entering warmup loop >> "%LOGFILE%"

:COUNTDOWN
echo [DEBUG] Remaining=!REMAIN! >> "%LOGFILE%"
if !REMAIN! LEQ 0 goto FINISH

if "%WRITE_MODE%"=="1" if exist "%BASEDIR%\STOP.txt" (
    echo [STOP] STOP.txt detected >> "%LOGFILE%"
    echo Run Status: ABORTED (STOP) >> "%HEALTHFILE%"
    goto CLEANUP
)

echo Remaining warm-up time: !REMAIN! minute(s)
timeout /t 60 /nobreak >nul
set /a REMAIN-=1
goto COUNTDOWN

:: ==================================================
:: FINISH
:: ==================================================
:FINISH
color 07
echo [STEP] Warmup complete >> "%LOGFILE%"

for /f %%A in ('wmic os get localdatetime ^| find "."') do set DTS=%%A
set ENDTIME=%DTS:~8,2%:%DTS:~10,2%

if "%WRITE_MODE%"=="1" (
    echo End Time: %ENDTIME% >> "%HEALTHFILE%"
    echo Run Status: COMPLETED >> "%HEALTHFILE%"
)

:: ==================================================
:: MONTHLY REPORT
:: ==================================================
if "%WRITE_MODE%"=="1" (
    echo [STEP] Updating monthly report >> "%LOGFILE%"
    if not exist "%MONTHLYFILE%" (
        echo PC ID: %PCID% > "%MONTHLYFILE%"
        echo Month: %CURRDATE:~0,7% >> "%MONTHLYFILE%"
        echo Total Runs: 0 >> "%MONTHLYFILE%"
    )

    for /f "tokens=3" %%A in ('find "Total Runs:" "%MONTHLYFILE%"') do set RUNS=%%A
    set /a RUNS+=1

    > "%MONTHLYFILE%" (
        echo PC ID: %PCID%
        echo Month: %CURRDATE:~0,7%
        echo Total Runs: %RUNS%
        echo Last Run: %CURRDATE% %ENDTIME%
    )
)

:: ==================================================
:: CLEANUP
:: ==================================================
:CLEANUP
echo [STEP] Cleaning CPU load >> "%LOGFILE%"
taskkill /F /IM cpu_load.cmd >nul 2>&1
echo [OK] CPU load stopped >> "%LOGFILE%"

echo [STEP] Initiating shutdown timer >> "%LOGFILE%"
shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."

echo ===== SCRIPT END %date% %time% ===== >> "%LOGFILE%"
exit /b 0
