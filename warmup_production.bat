@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production (SECONDS MODE)

:: ==================================================
:: BASE PATHS
:: ==================================================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set CPULOADER=%BASEDIR%\cpu_load.cmd
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health
set MONTHLYDIR=%HEALTHDIR%\Monthly

if not exist "%BASEDIR%" mkdir "%BASEDIR%"
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%"

echo. >> "%LOGFILE%"
echo ===== SCRIPT START %date% %time% ===== >> "%LOGFILE%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [STEP] Checking admin rights >> "%LOGFILE%"
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Not running as admin >> "%LOGFILE%"
    pause
    exit /b 1
)
echo [OK] Admin confirmed >> "%LOGFILE%"

:: ==================================================
:: CONFIGURATION (SECONDS)
:: ==================================================
set WARMUP_SECONDS=1800
set SHUTDOWN_WARNING_SECONDS=120

echo [CONFIG] Warmup=%WARMUP_SECONDS% sec Shutdown=%SHUTDOWN_WARNING_SECONDS% sec >> "%LOGFILE%"

:: ==================================================
:: WRITE MODE CHECK
:: ==================================================
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
echo [INFO] PC ID=%PCID% >> "%LOGFILE%"

:: ==================================================
:: DATE / TIME (SAFE)
:: ==================================================
for /f %%A in ('wmic os get localdatetime ^| find "."') do set DTS=%%A
set CURRDATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
set STARTTIME=%DTS:~8,2%:%DTS:~10,2%

set HEALTHFILE=%HEALTHDIR%\Health_%CURRDATE%_%PCID%.txt
set MONTHLYFILE=%MONTHLYDIR%\Monthly_%CURRDATE:~0,7%_%PCID%.txt

:: ==================================================
:: CPU LOAD CALCULATION
:: ==================================================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1
echo [INFO] CPU cores=%CORES% LoadThreads=%LOAD% >> "%LOGFILE%"

:: ==================================================
:: HEALTH FILE HEADER
:: ==================================================
if "%WRITE_MODE%"=="1" (
    echo PC ID: %PCID% > "%HEALTHFILE%"
    echo Date: %CURRDATE% >> "%HEALTHFILE%"
    echo Start Time: %STARTTIME% >> "%HEALTHFILE%"
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
:: W
