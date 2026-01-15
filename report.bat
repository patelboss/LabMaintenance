@echo off
setlocal EnableDelayedExpansion

:: Read PC ID
set /p PCID=<C:\LabMaintenance\pc_id.txt

set LOG=C:\LabMaintenance\log.txt
set REPORT=C:\LabMaintenance\Monthly_Report_%PCID%.txt

:: Count runs
find /c "Started:" "%LOG%" > temp.txt
set /p RUNS=<temp.txt
del temp.txt

:: Get last run
for /f "delims=" %%A in ('find "Started:" "%LOG%"') do set LAST=%%A

:: Write report
echo ============================== > "%REPORT%"
echo PC ID: %PCID% >> "%REPORT%"
echo Month: %date% >> "%REPORT%"
echo Total Warm-up Runs: %RUNS% >> "%REPORT%"
echo Last Run: %LAST% >> "%REPORT%"
echo Status: OK >> "%REPORT%"
echo ============================== >> "%REPORT%"
