@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ===============================
:: Admin Check
:: ===============================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run this script as Administrator.
    pause
    exit /b 1
)

:: ===============================
:: Paths (NO embedded quotes)
:: ===============================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt

:: ===============================
:: Emergency Stop
:: ===============================
if exist "%BASEDIR%\STOP.txt" (
    echo Emergency STOP detected. >> "%LOGFILE%"
    echo STOP.txt present. Script aborted.
    exit /b 0
)

:: ===============================
:: Read PC ID
:: ===============================
if not exist "%PCIDFILE%" (
    echo ERROR: pc_id.txt missing >> "%LOGFILE%"
    echo pc_id.txt missing. Exiting.
    exit /b 1
)
set /p PCID=<"%PCIDFILE%"

:: ===============================
:: Log Start
:: ===============================
echo ============================== >> "%LOGFILE%"
echo PC ID: %PCID% >> "%LOGFILE%"
echo Start: %date% %time% >> "%LOGFILE%"

:: ===============================
:: Auto CPU Load Detection
:: ===============================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

echo CPU Cores: %CORES% >> "%LOGFILE%"
echo Load Threads: %LOAD% >> "%LOGFILE%"

:: ===============================
:: Start CPU Load (Tagged)
:: ===============================
for /L %%A in (1,1,%LOAD%) do (
    start "LAB_CPU_LOAD" /B cmd /c "for /L %%B in () do rem"
)
echo CPU load started >> "%LOGFILE%"

:: ===============================
:: Disk Activity (Light)
:: ===============================
for /L %%C in (1,1,2) do (
    fsutil file createnew "%BASEDIR%\temp%%C.tmp" 20000000 >nul 2>&1
    del "%BASEDIR%\temp%%C.tmp" >nul 2>&1
)
echo Disk activity done >> "%LOGFILE%"

:: ===============================
:: Warm-up (TEST MODE ~3 min)
:: ===============================
timeout /t 180 /nobreak >nul

:: ===============================
:: Stop CPU Load Safely
:: ===============================
taskkill /F /FI "WINDOWTITLE eq LAB_CPU_LOAD" >nul 2>&1
echo CPU load stopped >> "%LOGFILE%"

:: ===============================
:: Cool-down (1 min)
:: ===============================
timeout /t 60 /nobreak >nul

:: ===============================
:: Shutdown Warning (2 min)
:: ===============================
shutdown /s /t 120 /c "Lab maintenance complete on %PCID%. Shutdown in 2 minutes. Use 'shutdown /a' to cancel."

echo End: %date% %time% >> "%LOGFILE%"
echo Status: Shutdown initiated >> "%LOGFILE%"

endlocal
exit /b 0
