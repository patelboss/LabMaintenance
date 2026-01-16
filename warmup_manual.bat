@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance Warm-up

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
    echo STOP detected. >> "%LOGFILE%"
    exit /b 0
)

:: ===============================
:: READ PC ID
:: ===============================
if not exist "%PCIDFILE%" exit /b 1
set /p PCID=<"%PCIDFILE%"

:: ===============================
:: DATE FORMATTING (SAFE)
:: ===============================
for /f %%A in ('wmic os get localdatetime ^| find "."') do set DT=%%A
set DATE=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%
set TIME=%DT:~8,2%:%DT:~10,2%

set HEALTHFILE=%HEALTHDIR%\Health_%DATE%_%PCID%.txt

:: ===============================
:: LOG START
:: ===============================
echo ============================== >> "%LOGFILE%"
echo PC ID: %PCID% >> "%LOGFILE%"
echo Start: %DATE% %TIME% >> "%LOGFILE%"

:: ===============================
:: CPU AUTO LOAD
:: ===============================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

:: ===============================
:: WRITE HEALTH HEADER
:: ===============================
echo PC ID: %PCID% > "%HEALTHFILE%"
echo Date: %DATE% >> "%HEALTHFILE%"
echo Start Time: %TIME% >> "%HEALTHFILE%"
echo CPU Cores: %CORES% >> "%HEALTHFILE%"
echo Load Threads: %LOAD% >> "%HEALTHFILE%"

:: ===============================
:: START CPU LOAD
:: ===============================
for /L %%A in (1,1,%LOAD%) do (
    start "LAB_CPU_LOAD_%PCID%" /B cmd /c "for /L %%B in () do rem"
)

echo CPU load started >> "%LOGFILE%"

:: ===============================
:: DISK ACTIVITY
:: ===============================
for /L %%C in (1,1,2) do (
    fsutil file createnew "%BASEDIR%\temp%%C.tmp" 20000000 >nul 2>&1
    del "%BASEDIR%\temp%%C.tmp" >nul 2>&1
)

echo Disk Activity: OK >> "%HEALTHFILE%"

:: ===============================
:: WARM-UP LOOP (Ctrl+C SAFE)
:: ===============================
set SECONDS=180
:WAITLOOP
timeout /t 5 >nul
set /a SECONDS-=5
if %SECONDS% GTR 0 goto WAITLOOP

:: ===============================
:: CLEANUP SECTION
:: ===============================
:CLEANUP
taskkill /F /FI "WINDOWTITLE eq LAB_CPU_LOAD_%PCID%" >nul 2>&1

for /f %%A in ('wmic os get localdatetime ^| find "."') do set DT=%%A
set ETIME=%DT:~8,2%:%DT:~10,2%

echo End Time: %ETIME% >> "%HEALTHFILE%"
echo Run Status: COMPLETED >> "%HEALTHFILE%"

echo End: %DATE% %ETIME% >> "%LOGFILE%"

shutdown /s /t 120 /c "Maintenance complete on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."
exit /b 0
