@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Stable Execution Mode

echo ==================================================
echo   LAB MAINTENANCE SCRIPT INITIALIZING
echo ==================================================
echo If you can read this, the script has started.
echo.

:: ==================================================
:: BASE LOCATION
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1

:: ==================================================
:: LOG INIT (UNCONDITIONAL)
:: ==================================================
type nul >> "%LOGFILE%" 2>nul
>>"%LOGFILE%" echo ===== SCRIPT START %date% %time% =====

:: ==================================================
:: ADMIN CHECK
:: ==================================================
echo [STEP] Verifying administrator rights
>>"%LOGFILE%" echo [STEP] Verifying administrator rights

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Administrator rights required
    >>"%LOGFILE%" echo [ERROR] Administrator rights required
    pause
    goto HOLD
)

echo [OK] Administrator rights confirmed
>>"%LOGFILE%" echo [OK] Administrator rights confirmed

:: ==================================================
:: CONFIGURATION
:: ==================================================
set WARMUP_SECONDS=20
set COOLDOWN_SECONDS=20
set SHUTDOWN_WARNING_SECONDS=20

:: ==================================================
:: PC ID
:: ==================================================
if not exist "%PCIDFILE%" (
    echo [SETUP] Enter PC ID:
    set /p PCID=
    echo %PCID% > "%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"

echo [INFO] PC ID: %PCID%
>>"%LOGFILE%" echo [INFO] PC ID: %PCID%

:: ==================================================
:: HEALTH SUMMARY (WMIC SAFE ZONE)
:: ==================================================
echo [STEP] Collecting system health summary
>>"%LOGFILE%" echo [STEP] Collecting system health summary

REM ---- Disable delayed expansion ONLY for WMIC ----
setlocal DisableDelayedExpansion

:: Safe date/time
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set DT=%%I
set H_DATE=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%
set H_TIME=%DT:~8,2%%DT:~10,2%

set HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%H_DATE%_%H_TIME%.txt

:: Last boot time
set BOOT=Unknown
for /f "tokens=2 delims==" %%B in ('wmic os get lastbootuptime /value 2^>nul') do set BOOT=%%B

:: Available RAM (MB)
set RAM=Unknown
for /f "tokens=2 delims==" %%R in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (
    set /a RAM=%%R / 1024
)

:: CPU temperature (best-effort, SAFE)
set TEMP=Not Available
for /f "tokens=2 delims==" %%T in (
 'wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2^>nul'
) do (
    if not "%%T"=="" (
        set /a RAW_TEMP=%%T
        set /a TEMP=(RAW_TEMP / 10) - 273
    )
)

(
echo PC ID               : %PCID%
echo Report Date         : %H_DATE%
echo Report Time         : %time%
echo Last System Boot    : %BOOT%
echo Available RAM (MB)  : %RAM%
echo CPU Temperature (C): %TEMP%
)> "%HEALTHFILE%"

endlocal
REM ---- Delayed expansion restored ----

echo [OK] Health summary saved
>>"%LOGFILE%" echo [OK] Health summary saved: %HEALTHFILE%

:: ==================================================
:: CPU LOAD
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

echo [STEP] Starting CPU load (%LOAD% workers)
>>"%LOGFILE%" echo [STEP] Starting CPU load (%LOAD% workers)

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_CPU_LOAD" /min cmd /c "for /L %%i in () do rem"
)

:: ==================================================
:: WARM-UP
:: ==================================================
set REMAIN=%WARMUP_SECONDS%
color 0B
:WARMUP_LOOP
cls
echo WARM-UP: %REMAIN% sec remaining
if %REMAIN% LEQ 0 goto WARMUP_DONE
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
goto WARMUP_LOOP

:WARMUP_DONE
color 07

echo [STEP] Stopping CPU load
>>"%LOGFILE%" echo [STEP] Stopping CPU load
taskkill /F /FI "WINDOWTITLE eq MAINT_CPU_LOAD*" /IM cmd.exe >nul 2>&1
echo [OK] CPU load stopped
>>"%LOGFILE%" echo [OK] CPU load stopped

:: ==================================================
:: COOLDOWN
:: ==================================================
set CD=%COOLDOWN_SECONDS%
color 0A
:COOLDOWN_LOOP
cls
echo COOLDOWN: %CD% sec remaining
if %CD% LEQ 0 goto COOLDOWN_DONE
timeout /t 1 /nobreak >nul
set /a CD-=1
goto COOLDOWN_LOOP

:COOLDOWN_DONE
color 07

:: ==================================================
:: SHUTDOWN
:: ==================================================
>>"%LOGFILE%" echo ===== SCRIPT END %date% %time% =====

shutdown /s /t %SHUTDOWN_WARNING_SECONDS% /c "Maintenance completed on %PCID%. Use shutdown /a to cancel."

:HOLD
pause >nul
goto HOLD
