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
set "WALLSRC=%BASE%wallpaper.png"

set "PROGDIR=C:\Program Files\Lab_Data"
set "WALLDEST=C:\Windows\Web\Wallpaper\LabWallpaper.png"

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
:: INSTALL FONTS (Copy + Registry Register)
:: ==================================================
if exist "%FONTS%" (
    echo [1/7] Installing Fonts...
    copy "%FONTS%\*" "%windir%\Fonts\" /y >nul
    :: This PowerShell snippet registers the fonts in the Registry
    powershell -command "$objShell = New-Object -ComObject Shell.Application; $objFolder = $objShell.Namespace(0x14); Get-ChildItem '%FONTS%' | ForEach-Object { $objFolder.CopyHere($_.FullName, 0x10) }"
)

:: ==================================================
:: CLEAN DESKTOP (Public and Current User)
:: ==================================================
echo [2/7] Cleaning Desktop Icons...
del "%PUBLIC%\Desktop\*" /f /q >nul 2>&1
del "%USERPROFILE%\Desktop\*" /f /q >nul 2>&1

:: ==================================================
:: COPY ICONS
:: ==================================================
if exist "%ICONS%" (
    echo [3/7] Deploying Lab Icons...
    xcopy "%ICONS%\*" "%PUBLIC%\Desktop\" /s /e /y /i >nul
)

:: ==================================================
:: COPY LAB DATA
:: ==================================================
if exist "%LABDATA%" (
    echo [4/7] Copying Lab Data to Program Files...
    if not exist "%PROGDIR%" mkdir "%PROGDIR%"
    xcopy "%LABDATA%\*" "%PROGDIR%\" /s /e /y /i >nul
)

:: ==================================================
:: INSTALL SOFTWARE (Silent)
:: ==================================================
echo [5/7] Installing Google Earth...
if exist "%EARTH%" (
    start /wait "" "%EARTH%" /S /v/qn
)

echo [6/7] Installing QGIS...
if exist "%QGIS%" (
    msiexec /i "%QGIS%" /qn /norestart
)

:: ==================================================
:: SET WALLPAPER
:: ==================================================
echo [7/7] Setting Wallpaper...
if exist "%WALLSRC%" (
    if not exist "C:\Windows\Web\Wallpaper" mkdir "C:\Windows\Web\Wallpaper"
    copy "%WALLSRC%" "%WALLDEST%" /y >nul
    
    reg add "HKCU\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "%WALLDEST%" /f >nul
    reg add "HKCU\Control Panel\Desktop" /v WallpaperStyle /t REG_SZ /d 2 /f >nul
    
    :: Force refresh
    powershell -command "Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Wallpaper { [DllImport(\"user32.dll\", CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); }'; [Wallpaper]::SystemParametersInfo(20, 0, '%WALLDEST%', 3)"
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
