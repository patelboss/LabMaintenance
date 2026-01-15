@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Maintenance One-Tap Installer

echo ===============================
echo Lab Maintenance Installer
echo ===============================

:: -------------------------------
:: ADMIN CHECK
:: -------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Administrator permission required.
    echo Right-click install.bat → Run as Administrator.
    pause
    exit /b 1
)

:: -------------------------------
:: DEFINE PATHS
:: -------------------------------
set SRC=%~dp0
set DEST=C:\LabMaintenance
set LOG=%DEST%\install_log.txt

:: -------------------------------
:: CREATE DESTINATION
:: -------------------------------
if not exist "%DEST%" (
    mkdir "%DEST%"
    if errorlevel 1 (
        echo ERROR: Cannot create %DEST%
        pause
        exit /b 1
    )
)

:: -------------------------------
:: VERIFY REQUIRED FILES
:: -------------------------------
set MISSING=0

for %%F in (warmup_manual.bat report_monthly.bat pc_id.txt) do (
    if not exist "%SRC%%%F" (
        echo Missing file: %%F
        set
