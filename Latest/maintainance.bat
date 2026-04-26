@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Master Controller

:: Always switch to script directory
cd /d "%~dp0"

echo ==========================================
echo        LAB MASTER CONTROLLER
echo ==========================================

echo [STEP 1] Running Health Script...
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Get-PCHealth.ps1"

if errorlevel 1 (
    echo [ERROR] Health Script Failed.
#    pause
    exit /b
)

echo [STEP 2] Running CPU Maintenance...
call "%~dp0cpu-maintenance.bat"

echo ==========================================
echo        MASTER PROCESS COMPLETE
echo ==========================================
