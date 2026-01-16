@echo off
setlocal EnableExtensions EnableDelayedExpansion

set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt

if not exist "%PCIDFILE%" exit /b 1
set /p PCID=<"%PCIDFILE%"

set REPORT=%BASEDIR%\Monthly_Report_%PCID%.txt

:: Correctly extract run count
for /f "tokens=2 delims=:" %%A in ('find /c "Start:" "%LOGFILE%"') do (
    set RUNS=%%A
)

:: Get last run safely
for /f "delims=" %%A in ('find "Start:" "%LOGFILE%"') do (
    set LAST=%%A
)

echo ============================== > "%REPORT%"
echo PC ID: %PCID% >> "%REPORT%"
echo Report Date: %date% >> "%REPORT%"
echo Total Runs: %RUNS% >> "%REPORT%"
echo Last Run: %LAST% >> "%REPORT%"
echo Status: OK >> "%REPORT%"
echo ============================== >> "%REPORT%"

endlocal
