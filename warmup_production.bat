@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production

:: ===============================
:: ADMIN CHECK
:: ===============================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run as Administrator.
    pause
    exit /b 1
)

:: ===============================
:: CONFIGURATION (EDIT HERE ONLY)
:: ===============================
set WARMUP_MINUTES=30
set SHUTDOWN_WARNING_SECONDS=120

:: ===============================
:: PATHS
:: ===============================
set BASEDIR=C:\LabMaintenance
set CPULOADER=%BASEDIR%\cpu_load.cmd
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health
set MONTHLYDIR=%HEALTHDIR%\Monthly
set LOGFILE=%BASEDIR%\log.txt

if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%"

:: ===============================
:: WRITE / READ-ONLY MODE DETECT
:: ===============================
set WRITE_MODE=0
echo test > "%BASEDIR%\.__write_test.tmp" 2>nul
if exist "%BASEDIR%\.__write_test.tmp" (
    del "%BASEDIR%\.__write_test.tmp" >nul 2>&1
    set WRITE_MODE=1
)

if "%WRITE_MODE%"=="1" (
    echo [MODE] WRITE MODE ENABLED
) else (
    echo [MODE] READ-ONLY SAFE MODE
)

:: ===============================
:: READ PC ID
:: ===============================
if not exist "%PCIDFILE%" exit /b 1
set /p PCID=<"%PCIDFILE%"

:: ===============================
:: DATE & TIME (SAFE)
:: ===============================
for /f %%A in ('wmic os get localdatetime ^| find "."') do set DTS=%%A
set CURRDATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
set CURRTIME=%DTS:~8,2%:%DTS:~10,2%
set CURRMONTH=%DTS:~0,4%-%DTS:~4,2%

set HEALTHFILE=%HEALTHDIR%\Health_%CURRDATE%_%PCID%.txt
set MONTHLYFILE=%MONTHLYDIR%\Monthly_%CURRMONTH%_%PCID%.txt

:: ===============================
:: LOG START (TEMP)
:: ===============================
if "%WRITE_MODE%"=="1" (
    echo ============================== >> "%LOGFILE%"
    echo PC ID: %PCID% >> "%LOGFILE%"
    echo Start: %CURRDATE% %CURRTIME% >> "%LOGFILE%"
)

:: ===============================
:: CPU LOAD CALCULATION
:: ===============================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

:: ===============================
:: HEALTH SUMMARY (DAY-WISE)
:: ===============================
if "%WRITE_MODE%"=="1" (
    echo PC ID: %PCID% > "%HEALTHFILE%"
    echo Date: %CURRDATE% >> "%HEALTHFILE%"
    echo Start Time: %CURRTIME% >> "%HEALTHFILE%"
    echo CPU Cores: %CORES% >> "%HEALTHFILE%"
    echo Load Threads: %LOAD% >> "%HEALTHFILE%"
)

:: ===============================
:: START CPU LOAD (SAFE)
:: ===============================
for /L %%A in (1,1,%LOAD%) do (
    start "" /B "%CPULOADER%"
)

:: ===============================
:: WARM-UP COUNTDOWN (BLUE)
:: ===============================
set REMAIN=%WARMUP_MINUTES%
color 0B

:COUNTDOWN
if %REMAIN% LEQ 0 goto FINISH

if "%WRITE_MODE%"=="1" if exist "%BASEDIR%\STOP.txt" (
    if "%WRITE_MODE%"=="1" echo Run Status: ABORTED (STOP) >> "%HEALTHFILE%"
    goto CLEANUP
)

echo Remaining warm-up time: %REMAIN% minute(s)
timeout /t 60 /nobreak >nul
set /a REMAIN-=1
goto COUNTDOWN

:: ===============================
:: FINISH NORMAL
:: ===============================
:FINISH
color 07

for /f %%A in ('wmic os get localdatetime ^| find "."') do set DTS=%%A
set ENDTIME=%DTS:~8,2%:%DTS:~10,2%

if "%WRITE_MODE%"=="1" (
    echo End Time: %ENDTIME% >> "%HEALTHFILE%"
    echo Run Status: COMPLETED >> "%HEALTHFILE%"
)

:: ===============================
:: MONTHLY REPORT UPDATE
:: ===============================
if "%WRITE_MODE%"=="1" (
    if not exist "%MONTHLYFILE%" (
        echo PC ID: %PCID% > "%MONTHLYFILE%"
        echo Month: %CURRMONTH% >> "%MONTHLYFILE%"
        echo Total Runs: 0 >> "%MONTHLYFILE%"
    )

    for /f "tokens=3" %%A in ('find "Total Runs:" "%MONTHLYFILE%"') do set RUNS=%%A
    set /a RUNS+=1

    > "%MONTHLYFILE%" (
        echo PC ID: %PCID%
        echo Month: %CURRMONTH%
        echo Total Runs: %RUNS%
        echo Last Run: %CURRDATE% %ENDTIME%
    )
)

:: ===============================
:: CLEANUP
:: ===============================
:CLEANUP
taskkill /F /IM cpu_load.cmd >nul 2>&1

if "%WRITE_MODE%"=="1" (
    echo End: %CURRDATE% %ENDTIME% >> "%LOGFILE%"
)

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."
exit /b 0
