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
:: LOG INIT
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
:: HEALTH SUMMARY (SAFE)
:: ==================================================
echo [STEP] Collecting system health summary
>>"%LOGFILE%" echo [STEP] Collecting system health summary

setlocal DisableDelayedExpansion

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set DT=%%I
set H_DATE=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%
set H_TIME=%DT:~8,2%%DT:~10,2%

set HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%H_DATE%_%H_TIME%.txt

set BOOT=Unknown
for /f "tokens=2 delims==" %%B in ('wmic os get lastbootuptime /value 2^>nul') do set BOOT=%%B

set RAM=Unknown
for /f "tokens=2 delims==" %%R in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (
    set /a RAM=%%R / 1024
)

(
echo PC ID              : %PCID%
echo Report Date        : %H_DATE%
echo Report Time        : %time%
echo Last System Boot   : %BOOT%
echo Available RAM (MB) : %RAM%
)> "%HEALTHFILE%"

endlocal

echo [OK] Health summary saved
>>"%LOGFILE%" echo [OK] Health summary saved

:: ==================================================
:: CPU LOAD
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_CPU_LOAD" /min cmd /c "for /L %%i in () do rem"
)

:: ==================================================
:: WARM-UP
:: ==================================================
set REMAIN=20
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

taskkill /F /FI "WINDOWTITLE eq MAINT_CPU_LOAD*" /IM cmd.exe >nul 2>&1

:: ==================================================
:: SHUTDOWN
:: ==================================================
>>"%LOGFILE%" echo ===== SCRIPT END %date% %time% =====
shutdown /s /t 20 /c "Maintenance completed on %PCID%. Use shutdown /a to cancel."

:HOLD
pause >nul
goto HOLD
