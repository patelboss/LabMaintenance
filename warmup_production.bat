@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production

:: ==================================================
:: ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run as Administrator.
    pause
    exit /b 1
)

:: ==================================================
:: CONFIGURATION (EDIT ONLY HERE)
:: ==================================================
set WARMUP_MINUTES=30
set SHUTDOWN_WARNING_SECONDS=120
set ENABLE_DISK_ACTIVITY=0

:: ==================================================
:: PATHS
:: ==================================================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health
set CPULOADER=%BASEDIR%\cpu_load.cmd

if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"

:: ==================================================
:: READ PC ID
:: ==================================================
if not exist "%PCIDFILE%" exit /b 1
set /p PCID=<"%PCIDFILE%"

:: ==================================================
:: STABLE DATE/TIME (NO SYSTEM VAR OVERRIDE)
:: ==================================================
for /f %%A in ('wmic os get localdatetime ^| find "."') do set DTS=%%A
set CURRDATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
set STARTTIME=%DTS:~8,2%:%DTS:~10,2%

set HEALTHFILE=%HEALTHDIR%\Health_%CURRDATE%_%PCID%.txt

:: ==================================================
:: LOG START
:: ==================================================
echo ============================== >> "%LOGFILE%"
echo PC ID: %PCID% >> "%LOGFILE%"
echo Start: %CURRDATE% %STARTTIME% >> "%LOGFILE%"

:: ==================================================
:: CPU AUTO LOAD (~50–60%)
:: ==================================================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

:: ==================================================
:: HEALTH FILE HEADER
:: ==================================================
echo PC ID: %PCID% > "%HEALTHFILE%"
echo Date: %CURRDATE% >> "%HEALTHFILE%"
echo Start Time: %STARTTIME% >> "%HEALTHFILE%"
echo CPU Cores: %CORES% >> "%HEALTHFILE%"
echo Load Threads: %LOAD% >> "%HEALTHFILE%"

:: ==================================================
:: START CPU LOAD (SAFE – IMAGE BASED)
:: ==================================================
for /L %%A in (1,1,%LOAD%) do (
    start "" /B "%CPULOADER%"
)

echo CPU load started >> "%LOGFILE%"

:: ==================================================
:: OPTIONAL DISK ACTIVITY (SAFE)
:: ==================================================
if "%ENABLE_DISK_ACTIVITY%"=="1" (
    dir C:\Windows\System32 >nul
    echo Disk Activity: READ ONLY >> "%HEALTHFILE%"
)

:: ==================================================
:: WARM-UP COUNTDOWN (ABORTABLE + STOP CHECK)
:: ==================================================
set REMAIN=%WARMUP_MINUTES%
color 0B

:COUNTDOWN
if %REMAIN% LEQ 0 goto END_WARMUP

if exist "%BASEDIR%\STOP.txt" (
    echo Emergency STOP triggered >> "%LOGFILE%"
    echo Run Status: ABORTED (STOP.txt) >> "%HEALTHFILE%"
    goto CLEANUP_ABORT
)

echo Remaining warm-up time: %REMAIN% minute(s)
timeout /t 60 /nobreak >nul
set /a REMAIN-=1
goto COUNTDOWN

:: ==================================================
:: NORMAL COMPLETION
:: ==================================================
:END_WARMUP
color 07

taskkill /F /IM cpu_load.cmd >nul 2>&1

for /f %%A in ('wmic os get localdatetime ^| find "."') do set DTS=%%A
set ENDTIME=%DTS:~8,2%:%DTS:~10,2%

echo End Time: %ENDTIME% >> "%HEALTHFILE%"
echo Run Status: COMPLETED >> "%HEALTHFILE%"

echo End: %CURRDATE% %ENDTIME% >> "%LOGFILE%"

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Lab maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."
exit /b 0

:: ==================================================
:: ABORT CLEANUP
:: ==================================================
:CLEANUP_ABORT
color 07
taskkill /F /IM cpu_load.cmd >nul 2>&1
echo CPU load terminated >> "%LOGFILE%"
exit /b 0
