@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Health Debug Probe – Windows 11 Safe

echo ==================================================
echo   HEALTH DEBUG SCRIPT – STARTING
echo ==================================================
echo.

:: --------------------------------------------------
:: PATHS
:: --------------------------------------------------
set "BASEDIR=%~dp0Maintenance_Data"
set "HEALTHDIR=%BASEDIR%\Health"
set "LOGFILE=%BASEDIR%\health_debug.log"

if not exist "%BASEDIR%" mkdir "%BASEDIR%" >nul 2>&1
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%" >nul 2>&1

:: --------------------------------------------------
:: LOG FUNCTION
:: --------------------------------------------------
:LOG
set "LVL=%~1"
set "MSG=%~2"
echo [%LVL%] %MSG%
echo [%LVL%] %MSG%>>"%LOGFILE%"
exit /b

:: --------------------------------------------------
:: START
:: --------------------------------------------------
> "%LOGFILE%" echo ===== HEALTH DEBUG START %date% %time% =====
call :LOG INFO "BaseDir=%BASEDIR%"
call :LOG INFO "HealthDir=%HEALTHDIR%"

:: --------------------------------------------------
:: WRITE PERMISSION TEST
:: --------------------------------------------------
call :LOG STEP "Testing write permissions"
echo test>"%BASEDIR%\.__write_test.tmp" 2>nul

if exist "%BASEDIR%\.__write_test.tmp" (
    del "%BASEDIR%\.__write_test.tmp"
    call :LOG OK "Write permission OK"
) else (
    call :LOG ERROR "Write permission FAILED"
)

:: --------------------------------------------------
:: DATE & MONTH KEY (PowerShell – Win11 Safe)
:: --------------------------------------------------
call :LOG STEP "Collecting date/time keys"

for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format ddMMyyyyHHmm"') do set "TS=%%A"
for /f %%B in ('powershell -NoProfile -Command "Get-Date -Format MM-yyyy"') do set "MONTHKEY=%%B"

call :LOG INFO "Timestamp=%TS%"
call :LOG INFO "MonthKey=%MONTHKEY%"

:: --------------------------------------------------
:: RAM CHECK (PowerShell CIM)
:: --------------------------------------------------
call :LOG STEP "Collecting RAM data"

set "RAM_MB=Not Available"
for /f %%R in ('
 powershell -NoProfile -Command ^
 "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)"
') do set "RAM_MB=%%R"

call :LOG INFO "Free RAM=%RAM_MB% MB"

:: --------------------------------------------------
:: DISK CHECK (PowerShell CIM)
:: --------------------------------------------------
call :LOG STEP "Collecting disk space"

set "FREE_GB=Not Available"
for /f %%D in ('
 powershell -NoProfile -Command ^
 "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB)"
') do set "FREE_GB=%%D"

call :LOG INFO "Disk Free C:=%FREE_GB% GB"

:: --------------------------------------------------
:: CPU TEMPERATURE (BEST EFFORT – NON-FATAL)
:: --------------------------------------------------
call :LOG STEP "Collecting CPU temperature"

set "TEMP=Not Supported"
for /f %%T in ('
 powershell -NoProfile -Command ^
 "$t=Get-CimInstance -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue; if($t){[math]::Round(($t.CurrentTemperature/10)-273)}"
') do set "TEMP=%%T"

call :LOG INFO "CPU Temp=%TEMP% C"

:: --------------------------------------------------
:: HEALTH FILE CREATION TEST
:: --------------------------------------------------
call :LOG STEP "Testing health file creation"

set "HEALTHFILE=%HEALTHDIR%\Health_DEBUG_%TS%.txt"

(
 echo Timestamp     : %TS%
 echo MonthKey      : %MONTHKEY%
 echo Free RAM (MB) : %RAM_MB%
 echo Free Disk GB  : %FREE_GB%
 echo CPU Temp C    : %TEMP%
)> "%HEALTHFILE%" 2>nul

if exist "%HEALTHFILE%" (
    call :LOG OK "Health file created successfully"
    call :LOG INFO "File=%HEALTHFILE%"
) else (
    call :LOG ERROR "Health file creation FAILED"
)

:: --------------------------------------------------
:: END
:: --------------------------------------------------
call :LOG INFO "Health debug completed"
call :LOG INFO "Review: %LOGFILE%"

echo.
echo ==================================================
echo   HEALTH DEBUG COMPLETE
echo ==================================================
pause
exit /b
