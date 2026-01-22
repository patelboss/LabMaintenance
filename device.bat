@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Peripheral Audit Test

echo ==================================================
echo   PERIPHERAL AUDIT: HARDWARE CHECK
echo ==================================================
echo.

:: Reset variables
set "KBD_STATUS=MISSING"
set "MSE_STATUS=MISSING"
set "KBD_NAME=Unknown"
set "MSE_NAME=Unknown"

:: --- KEYBOARD CHECK ---
echo [CHECKING] Keyboard...
:: Get Description and Status
for /f "tokens=2 delims==" %%A in ('wmic path Win32_Keyboard get Description /value 2^>nul') do set "KBD_NAME=%%A"
wmic path Win32_Keyboard get Status /value 2>nul | findstr /i "OK" >nul
if %errorlevel% equ 0 (
    set "KBD_STATUS=OK (CONNECTED)"
) else (
    set "KBD_STATUS=ERROR/MISSING"
)

:: --- MOUSE CHECK ---
echo [CHECKING] Mouse...
for /f "tokens=2 delims==" %%B in ('wmic path Win32_PointingDevice get Description /value 2^>nul') do set "MSE_NAME=%%B"
wmic path Win32_PointingDevice get Status /value 2>nul | findstr /i "OK" >nul
if %errorlevel% equ 0 (
    set "MSE_STATUS=OK (CONNECTED)"
) else (
    set "MSE_STATUS=ERROR/MISSING"
)

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

