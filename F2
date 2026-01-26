@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Master Production (DEBUG SAFE)

:: ==================================================
:: [1] PATH SETUP
:: ==================================================
set "BASEDIR=%~dp0Maintenance_Data"
set "LOGFILE=%BASEDIR%\log.txt"
set "PCIDFILE=%BASEDIR%\pc_id.txt"
set "HEALTHDIR=%BASEDIR%\Health"
set "MONTHLYDIR=%BASEDIR%\Monthly"
set "SIGNAL=%temp%\maint_active.tmp"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1
if not exist "%MONTHLYDIR%" mkdir "%MONTHLYDIR%" >nul 2>&1
if exist "%SIGNAL%" del "%SIGNAL%" >nul 2>&1

:: ==================================================
:: [2] LOG FUNCTION (SCREEN + FILE)
:: ==================================================
if not exist "%LOGFILE%" echo.>"%LOGFILE%"

:LOG
echo [%~1] %~2
echo [%~1] %~2>>"%LOGFILE%"
exit /b

call :LOG INFO "SCRIPT STARTED"

:: ==================================================
:: [3] ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if errorlevel 1 (
    call :LOG ERROR "Administrator rights REQUIRED"
    pause
    goto HOLD
)
call :LOG OK "Administrator confirmed"

:: ==================================================
:: [4] PC ID
:: ==================================================
if not exist "%PCIDFILE%" (
    call :LOG SETUP "PC ID not found"
    set /p "NEW_ID=Enter PC ID: "
    echo !NEW_ID!>"%PCIDFILE%"
)
set /p PCID=<"%PCIDFILE%"
set "PCID=%PCID: =%"
call :LOG INFO "PC ID = %PCID%"

:: ==================================================
:: [5] SAFE DATE/TIME (DDMMYYYYHHMM)
:: ==================================================
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "DT=%%I"

set "YYYY=!DT:~0,4!"
set "MM=!DT:~4,2!"
set "DD=!DT:~6,2!"
set "HH=!DT:~8,2!"
set "MN=!DT:~10,2!"

set "STAMP=%DD%%MM%%YYYY%%HH%%MN%"
set "MONTHSTAMP=%MM%%YYYY%"

call :LOG INFO "Timestamp = %STAMP%"

:: ==================================================
:: [6] HEALTH FILE
:: ==================================================
set "HEALTHFILE=%HEALTHDIR%\Health_%PCID%_%STAMP%.txt"
call :LOG INFO "Health file: %HEALTHFILE%"

:: RAM
set "MEM=Unknown"
for /f "tokens=2 delims==" %%M in ('wmic OS get FreePhysicalMemory /value 2^>nul') do (
    set /a MEM=%%M/1024
)

:: CPU TEMP (SAFE)
set "TEMP=NotAvailable"
for /f "tokens=2 delims==" %%T in ('wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2^>nul') do (
    if not "%%T"=="" (
        set /a RAW_TEMP=%%T
        set /a TEMP=(RAW_TEMP/10)-273
    )
)

(
echo PC ID: %PCID%
echo Date-Time: %DD%-%MM%-%YYYY% %HH%:%MN%
echo Start RAM: %MEM% MB
echo CPU Temp: %TEMP% C
echo ---
)>"%HEALTHFILE%"

call :LOG OK "Health report created"

:: ==================================================
:: [7] CPU LOAD (WARM-UP)
:: ==================================================
set /a LOAD=%NUMBER_OF_PROCESSORS%/2
if %LOAD% LSS 1 set LOAD=1
echo active>"%SIGNAL%"

call :LOG INFO "Starting CPU load (%LOAD% workers)"

for /L %%A in (1,1,%LOAD%) do (
    start "MAINT_WORKER" /min cmd /c "for /L %%i in () do if not exist "%SIGNAL%" exit"
)

set REMAIN=20
color 0B
:WARMUP
cls
echo === WARM-UP MODE ===
echo PC: %PCID%
echo Remaining: %REMAIN%s
timeout /t 1 /nobreak >nul
set /a REMAIN-=1
if %REMAIN% GTR 0 goto WARMUP

:: ==================================================
:: [8] COOLDOWN
:: ==================================================
if exist "%SIGNAL%" del "%SIGNAL%"
set CD=20
color 0A
:COOLDOWN
cls
echo === COOLDOWN MODE ===
echo Remaining: %CD%s
timeout /t 1 /nobreak >nul
set /a CD-=1
if %CD% GTR 0 goto COOLDOWN
color 07

:: ==================================================
:: [9] FINALIZE HEALTH
:: ==================================================
for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value 2^>nul') do set "FREE_BYTES=%%D"
for /f %%G in ('powershell [math]::Round^(%FREE_BYTES%/1GB^)') do set "FREE_GB=%%G"

(
echo End Time: %time%
echo Free Disk: %FREE_GB% GB
echo Status: SUCCESS
)>>"%HEALTHFILE%"

call :LOG OK "Health report finalized"

:: ==================================================
:: [10] MONTHLY REPORT
:: ==================================================
set "MONTHLYFILE=%MONTHLYDIR%\Monthly_%PCID%_%MONTHSTAMP%.txt"
call :LOG INFO "Monthly file: %MONTHLYFILE%"

if not exist "%MONTHLYFILE%" (
    echo MONTHLY SUMMARY %MONTHSTAMP%>"%MONTHLYFILE%"
    echo PC ID: %PCID%>>"%MONTHLYFILE%"
    echo ------------------------------>>"%MONTHLYFILE%"
)

echo %STAMP% | Free: %FREE_GB% GB>>"%MONTHLYFILE%"
call :LOG OK "Monthly report updated"

:: ==================================================
:: [11] SHUTDOWN
:: ==================================================
call :LOG INFO "Maintenance complete – Shutdown in 60s"
shutdown /s /t 60 /c "Lab Maintenance complete on %PCID%"

:HOLD
echo.
echo === SCRIPT PAUSED ===
pause
goto HOLD
