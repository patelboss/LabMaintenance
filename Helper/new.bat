@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Setup Script

:: ==================================================
:: BASE DIRECTORY (Location of script)
:: ==================================================
set "BASE=%~dp0"

set "FONTS=%BASE%Fonts"
set "ICONS=%BASE%Icons"
set "LABDATA=%BASE%Lab_Data"
set "EARTH=%BASE%earth.exe"
set "QGIS=%BASE%QGIS.msi"
set "WALLSRC=%BASE%wallpaper.png"

set "DESKTOP=%PUBLIC%\Desktop"
set "PROGDIR=C:\Program Files\Lab_Data"
set "WALLDEST=C:\Windows\Web\wallpaper.png"

:: ==================================================
:: ADMIN CHECK
:: ==================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
 echo Requesting Administrator privileges...
 powershell -Command "Start-Process '%~f0' -Verb RunAs"
 exit
)

echo.
echo ======================================
echo LAB SETUP STARTING
echo ======================================
echo.

:: ==================================================
:: INSTALL FONTS
:: ==================================================
echo Installing Fonts...

if exist "%FONTS%" (
 for %%F in ("%FONTS%\*.ttf" "%FONTS%\*.otf") do (
  echo Installing %%~nxF
  copy "%%F" "%windir%\Fonts\" /y >nul
 )
)

:: ==================================================
:: CLEAN DESKTOP
:: ==================================================
echo Cleaning Desktop...
del "%DESKTOP%\*" /f /q >nul 2>&1

:: ==================================================
:: COPY ICONS
:: ==================================================
echo Copying Icons...

if exist "%ICONS%" (
 xcopy "%ICONS%\*" "%DESKTOP%\" /s /e /y /i >nul
)

:: ==================================================
:: COPY LAB DATA
:: ==================================================
echo Copying Lab Data...

if exist "%LABDATA%" (
 mkdir "%PROGDIR%" >nul 2>&1
 xcopy "%LABDATA%\*" "%PROGDIR%\" /s /e /y /i >nul
)

:: ==================================================
:: INSTALL GOOGLE EARTH
:: ==================================================
echo Installing Google Earth...

if exist "%EARTH%" (
 start /wait "" "%EARTH%" /silent /norestart
)

:: ==================================================
:: INSTALL QGIS
:: ==================================================
echo Installing QGIS...

if exist "%QGIS%" (
 msiexec /i "%QGIS%" /qn /norestart
)

:: ==================================================
:: SET WALLPAPER
:: ==================================================
echo Setting Wallpaper...

copy "%WALLSRC%" "%WALLDEST%" /y >nul

reg add "HKCU\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "%WALLDEST%" /f >nul
reg add "HKCU\Control Panel\Desktop" /v WallpaperStyle /t REG_SZ /d 2 /f >nul
reg add "HKCU\Control Panel\Desktop" /v TileWallpaper /t REG_SZ /d 0 /f >nul

RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters

:: ==================================================
:: RESTART COMPUTER
:: ==================================================
echo.
echo Setup Complete. Restarting in 10 seconds...
shutdown /r /t 10
