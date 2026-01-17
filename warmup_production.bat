@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production (No Helper)

:: ==================================================
:: BASE PATHS
:: ==================================================
set BASEDIR=C:\LabMaintenance
set LOGFILE=%BASEDIR%\log.txt
set PCIDFILE=%BASEDIR%\pc_id.txt
set HEALTHDIR=%BASEDIR%\Health
set MONTHLYDIR=%HEALTHDIR%\Monthly

if not exist "%BASEDIR%" mkdir "%BASEDIR%"
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%"

echo.>>"%LOGFILE%"
echo ===== SCRIPT START %date% %time% =====>>"%LOGFILE%"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [STEP] Checking admin rights>>"%LOGFILE%"
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Not admin>>"%LOGFILE%"
    pause
    exit /b 1
)
echo [OK] Admin confirmed>>"%LOGFILE%"

:: ==================================================
:: CONFIGURATION (SECONDS)
:: ==================================================
set WARMUP_SECONDS=1800
set SHUTDOWN_WARNING_SECONDS=120

echo [CONFIG] Warmup=%WARMUP_SECONDS% sec Shutdown=%SHUTDOWN_WARNING_SECONDS% sec>>"%LOGFILE%"

:: ==================================================
:: PC ID
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [ERROR] pc_id.txt missing>>"%LOGFILE%"
    exit /b 1
)
set /p PCID=<"%PCIDFILE%"
echo [INFO] PC ID=%PCID%>>"%LOGFILE%"

:: ==================================================
:: CPU LOAD CALCULATION (~50–60%)
:: ==================================================
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1
echo [INFO] CPU cores=%CORES% LoadWorkers=%LOAD%>>"%LOGFILE%"

:: ==================================================
:: START CPU LOAD (POWERSHELL – NO HELPER)
:: ==================================================
echo [STEP] Starting CPU load>>"%LOGFILE%"

for /L %%A in (1,1,%LOAD%) do (
    start "" powershell -NoProfile -WindowStyle Hidden ^
    -Command "$host.UI.RawUI.WindowTitle='LAB_CPU_LOAD_%PCID%'; while($true){$x=1}"
)

echo [OK] CPU load running>>"%LOGFILE%"

:: ==================================================
:: WARM-UP LOOP (SECONDS)
:: ==================================================
set REMAIN=%WARMUP_SECONDS%
color 0B
echo [STEP] Entering warmup loop>>"%LOGFILE%"

:COUNTDOWN
if !REMAIN! LEQ 0 goto FINISH

echo [DEBUG] RemainingSeconds=!REMAIN!>>"%LOGFILE%"
>>"%LOGFILE%" echo.
echo Remaining warm-up time: !REMAIN! second(s)

call :DELAY_1S
set /a REMAIN-=1
goto COUNTDOWN

:: ==================================================
:: FINISH
:: ==================================================
:FINISH
color 07
echo [STEP] Warmup completed>>"%LOGFILE%"

goto AFTER_WARMUP

:: ==================================================
:: AFTER WARM-UP
:: ==================================================
:AFTER_WARMUP
echo [STEP] Stopping CPU load>>"%LOGFILE%"

powershell -NoProfile -Command ^
"Get-Process powershell | Where-Object {$_.MainWindowTitle -eq 'LAB_CPU_LOAD_%PCID%'} | Stop-Process -Force"

echo [OK] CPU load stopped>>"%LOGFILE%"

echo [STEP] Shutdown timer started>>"%LOGFILE%"
shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Shutdown in 2 minutes. Use shutdown /a to cancel."

echo ===== SCRIPT END %date% %time% =====>>"%LOGFILE%"
exit /b 0

:: ==================================================
:: RELIABLE 1-SECOND DELAY
:: ==================================================
:DELAY_1S
ping 127.0
