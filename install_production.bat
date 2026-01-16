@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance – Production Installer

echo ====================================
echo Lab Maintenance Production Installer
echo ====================================

:: ==================================================
:: ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Administrator permission required.
    echo Right-click and choose "Run as administrator".
    pause
    exit /b 1
)

:: ==================================================
:: PATHS
:: ==================================================
set SRC=%~dp0
set DEST=C:\LabMaintenance
set HEALTHDIR=%DEST%\Health
set INSTALLLOG=%DEST%\install_log.txt

:: ==================================================
:: VERIFY REQUIRED FILES
:: ==================================================
set MISSING=0
for %%F in (warmup_production.bat cpu_load.cmd pc_id.txt) do (
    if not exist "%SRC%%%F" (
        echo MISSING FILE: %%F
        set MISSING=1
    )
)

if %MISSING%==1 (
    echo Installation aborted. Required files missing.
    pause
    exit /b 1
)

:: ==================================================
:: CREATE FOLDERS (NON-DESTRUCTIVE)
:: ==================================================
if not exist "%DEST%" mkdir "%DEST%"
if not exist "%HEALTHDIR%" mkdir "%HEALTHDIR%"

:: ==================================================
:: COPY FILES (SAFE OVERWRITE)
:: ==================================================
copy /Y "%SRC%warmup_production.bat" "%DEST%" >nul
copy /Y "%SRC%cpu_load.cmd" "%DEST%" >nul

:: Copy pc_id only if not already present
if not exist "%DEST%\pc_id.txt" (
    copy "%SRC%pc_id.txt" "%DEST%" >nul
)

:: ==================================================
:: INSTALL LOG
:: ==================================================
echo ============================== >> "%INSTALLLOG%"
echo Install Date: %date% %time% >> "%INSTALLLOG%"
echo Installed By: %USERNAME% >> "%INSTALLLOG%"
echo Source: %SRC% >> "%INSTALLLOG%"
echo Status: SUCCESS >> "%INSTALLLOG%"

:: ==================================================
:: FINAL MESSAGE
:: ==================================================
echo.
echo ====================================
echo INSTALLATION SUCCESSFUL
echo ====================================
echo Installed at: %DEST%
echo.
echo Next steps:
echo 1) Verify pc_id.txt
echo 2) Run warmup_production.bat AS ADMIN when needed
echo.
pause
exit /b 0
