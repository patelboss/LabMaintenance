@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production Mode

:: ===============================
:: ADMIN CHECK
:: ===============================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run this script as Administrator.
    pause
    exit /b 1
)

:: ===============================
:: CONFIGURATION (EDIT ONLY HERE)
:: ===============================
set WARMUP_MINUTES=30
set SHUTDOWN_WARNING_SECONDS=120

:: ===============================
:: PATHS
:: ===============================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health

if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"

:: ===============================
:: EMERGENCY STOP
:: ===============================
if exist "%BASEDIR%\STOP.txt" (
    echo Emergency STOP detected. >> "%LOGFILE%"
    echo STOP.txt present. Script aborted.
    exit /b 0
)

:: ===============================
:: READ PC ID
:: ===============================
if not exist "%PCIDFILE%" (
    echo ERROR: pc_id.txt missing >> "%LOGFILE%"
    exit /b 1
)
set /p PCID=<"%PCIDFILE%"

:: ===============================
:: DATE & TIME (STABLE FORMAT)
:: ===============================
for /f %%A in ('wmic os get localdatetime ^| find "."') do set DT=%%A
set DATE=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%
set STARTTIME=%DT:~8,2%:%DT:~10,2%
set ENDTIME=

set HEALTHFILE=%HEALTHDIR%\Health_%DATE%_%PCID%.txt

:: ===============================
:: LOG START
:: ===============================
echo ============================== >> "%LOGFILE%"
echo PC ID: %PCID% >> "%LOGFILE%"
echo Start: %DATE% %STARTTIME% >> "%LOGFILE%"

:: ===============================
:: CPU AUTO LOAD
:: ===============================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

:: ===============================
:: HEALTH FILE HEADER
:: ===============================
echo PC ID: %PCID% > "%HEALTHFILE%"
echo Date: %DATE% >> "%HEALTHFILE%"
echo Start Time: %STARTTIME% >> "%HEALTHFILE%"
echo CPU Cores: %CORES% >> "%HEALTHFILE%"
echo Load Threads: %LOAD% >> "%HEALTHFILE%"

:: ===============================
:: START CPU LOAD (TAGGED)
:: ===============================
for /L %%A in (1,1,%LOAD%) do (
    start "LAB_CPU_LOAD_%PCID%" /B cmd /c "for /L %%B in () do rem"
)

echo CPU load started >> "%LOGFILE%"

:: ===============================
:: DISK ACTIVITY (LIGHT)
:: ===============================
for /L %%C in (1,1,2) do (
    fsutil file createnew "%BASEDIR%\temp%%C.tmp" 20000000 >nul 2>&1
    del "%BASEDIR%\temp%%C.tmp" >nul 2>&1
)

echo Disk Activity: OK >> "%HEALTHFILE%"

:: ===============================
:: WARM-UP COUNTDOWN (BLUE TEXT)
:: ===============================
set REMAIN=%WARMUP_MINUTES%
color 0B

:COUNTDOWN
if %REMAIN% LEQ 0 goto END_WARMUP
echo Remaining warm-up time: %REMAIN% minute(s)
timeout /t 60 >nul
set /a REMAIN-=1
goto COUNTDOWN

:: ===============================
:: END WARM-UP
:: ===============================
:END_WARMUP
color 07

taskkill /F /FI "WINDOWTITLE eq LAB_CPU_LOAD_%PCID%" >nul 2>&1

for /f %%A in ('wmic os get localdatetime ^| find "."') do set DT=%%A
set ENDTIME=%DT:~8,2%:%DT:~10,2%

echo End Time: %ENDTIME% >> "%HEALTHFILE%"
echo Run Status: COMPLETED >> "%HEALTHFILE%"

echo End: %DATE% %ENDTIME% >> "%LOGFILE%"

:: ===============================
:: SHUTDOWN WARNING
:: ===============================
shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Lab maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."

endlocal
exit /b 0
