@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lab Setup Script

:: ==================================================
:: BASE DIRECTORY (location of this script)
:: ==================================================
set "BASE=%~dp0"

set "FONTS=%BASE%Fonts"
set "ICONS=%BASE%Icons"
set "LABDATA=%BASE%Lab_Data"
set "WALL=%BASE%wallpaper.png"

set "DESKTOP=%PUBLIC%\Desktop"
set "PROGDIR=C:\Program Files\Lab_Data"

:: ==================================================
:: CHECK ADMIN
:: ==================================================
net session >nul 2>&1
if errorlevel 1 (
 echo Requesting Administrator privileges...
 powershell -Command "Start-Process '%~f0' -Verb RunAs"
 exit
)

echo.
echo ===== Installing Fonts =====

if exist "%FONTS%" (
 for %%F in ("%FONTS%\*.ttf" "%FONTS%\*.otf") do (
  echo Installing %%~nxF
  copy "%%F" "%windir%\Fonts\" >nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /v "%%~nxF" /t REG_SZ /d "%%~nxF" /f >nul
 )
)

echo.
echo ===== Cleaning Desktop =====

del "%DESKTOP%\*" /f /q >nul 2>&1

echo.
echo ===== Copying Icons =====

if exist "%ICONS%" (
 xcopy "%ICONS%\*" "%DESKTOP%\" /s /e /y >nul
)

echo.
echo ===== Copying Lab Data =====

if exist "%LABDATA%" (
 mkdir "%PROGDIR%" >nul 2>&1
 xcopy "%LABDATA%\*" "%PROGDIR%\" /s /e /y >nul
)

echo.
echo ===== Installing Google Earth =====

if exist "%BASE%earth.exe" (
 start /wait "" "%BASE%earth.exe" /S
)

echo.
echo ===== Installing QGIS =====

if exist "%BASE%QGIS.msi" (
 msiexec /i "%BASE%QGIS.msi" /qn /norestart
)

echo.
echo ===== Setting Wallpaper =====

reg add "HKCU\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "%WALL%" /f >nul
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters

echo.
echo ===== Restarting Computer =====

shutdown /r /t 10
