@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Peripheral Audit Test (Win 11 Compatible)

echo ==================================================
echo   PERIPHERAL AUDIT: HARDWARE CHECK
echo ==================================================
echo.

:: --- KEYBOARD CHECK ---
echo [CHECKING] Keyboard...
for /f "delims=" %%A in ('powershell -command "Get-PnpDevice -ClassName Keyboard -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "KBD_NAME=%%A"
if defined KBD_NAME (set "KBD_STATUS=OK (CONNECTED)") else (set "KBD_STATUS=ERROR/MISSING" & set "KBD_NAME=None")

:: --- MOUSE CHECK ---
echo [CHECKING] Mouse...
for /f "delims=" %%B in ('powershell -command "Get-PnpDevice -ClassName Mouse -Status OK | Select-Object -ExpandProperty FriendlyName -First 1"') do set "MSE_NAME=%%B"
if defined MSE_NAME (set "MSE_STATUS=OK (CONNECTED)") else (set "MSE_STATUS=ERROR/MISSING" & set "MSE_NAME=None")

:: --- DISPLAY RESULTS ---
echo.
echo --------------------------------------------------
echo   RESULTS:
echo --------------------------------------------------
echo   KEYBOARD: %KBD_STATUS%
echo   MODEL:    %KBD_NAME%
echo.
echo   MOUSE:    %MSE_STATUS%
echo   MODEL:    %MSE_NAME%
echo --------------------------------------------------
echo.

:: Visual Alert Logic
if "%KBD_STATUS%"=="ERROR/MISSING" (
    color 0C
    echo [!] ALERT: Keyboard issue detected.
) else if "%MSE_STATUS%"=="ERROR/MISSING" (
    color 0C
    echo [!] ALERT: Mouse issue detected.
) else (
    color 0A
    echo [PASS] All essential input devices are healthy.
)

pause

