@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Setup Script - Enhanced

:: ==================================================
:: BASE DIRECTORY
:: ==================================================
set "BASE=%~dp0"
set "FONTS=%BASE%Fonts"
set "ICONS=%BASE%Icons"
set "LABDATA=%BASE%Lab_Data"
set "EARTH=%BASE%earth.exe"
set "QGIS=%BASE%QGIS.msi"
set "PEAZIP=%BASE%peazip-10.9.0.WIN64.exe"
set "WALLSRC=%BASE%wallpaper.png"

set "PROGDIR=C:\Program Files\Lab_Data"
set "WALLDEST=C:\wallpaper.png"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo ======================================
echo    RUNNING LAB DEPLOYMENT
echo ======================================

:: ==================================================
:: CLEAN DESKTOP (Public and Current User)
:: ==================================================
echo [1/8] Cleaning Desktop Icons...
del "%PUBLIC%\Desktop\*" /f /q >nul 2>&1
del "%USERPROFILE%\Desktop\*" /f /q >nul 2>&1

:: ==================================================
:: COPY ICONS
:: ==================================================
if exist "%ICONS%" (
    echo [2/8] Deploying Lab Icons...
    xcopy "%ICONS%\*" "%PUBLIC%\Desktop\" /s /e /y /i >nul
)

:: ==================================================
:: COPY LAB DATA
:: ==================================================
if exist "%LABDATA%" (
    echo [3/8] Copying Lab Data to Program Files...
    if not exist "%PROGDIR%" mkdir "%PROGDIR%"
    xcopy "%LABDATA%\*" "%PROGDIR%\" /s /e /y /i >nul
)

:: ==================================================
:: INSTALL SOFTWARE (Silent)
:: ==================================================
echo [4/8] Installing Google Earth...
if exist "%EARTH%" (

    start /wait "" "%EARTH%" OMAHA=1
)

echo [5/8] Installing QGIS...
if exist "%QGIS%" (
    msiexec /i "%QGIS%" /qn /norestart
)

echo [6/8] Installing PeaZip...
if exist "%PEAZIP%" (
    start /wait "" "%PEAZIP%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
)

:: ==================================================
:: COPY WALLPAPER FILE ONLY
:: ==================================================
echo [7/8] Copying Wallpaper to C:\...
if exist "%WALLSRC%" (
    copy "%WALLSRC%" "%WALLDEST%" /y >nul
)

:: ==================================================
:: INSTALL FONTS (Copy + Registry Register) - MOVED TO LAST
:: ==================================================
if exist "%FONTS%" (
    echo [8/8] Installing Fonts...
    copy "%FONTS%\*" "%windir%\Fonts\" /y >nul
    :: Registering fonts via PowerShell
    powershell -command "$objShell = New-Object -ComObject Shell.Application; $objFolder = $objShell.Namespace(0x14); Get-ChildItem '%FONTS%' | ForEach-Object { $objFolder.CopyHere($_.FullName, 0x10) }"
)

:: ==================================================
:: RESTART
:: ==================================================
echo.
echo Setup Complete. The system will restart in 15 seconds.
echo Press any key to restart immediately.
shutdown /r /t 15 /c "Lab Setup Complete. Rebooting to apply all changes."
pause >nul
shutdown /r /t 0
