@echo off
setlocal enabledelayedexpansion

echo Testing logic... Press 'C' or wait for 'N' (60s)
choice /c cn /t 60 /d n /n >nul 2>&1

echo Actual Errorlevel received: !errorlevel!

if !errorlevel! equ 1 (
    color 0E
    echo [RESULT] Value is equal to 1. (This would ABORT shutdown)
) else (
    color 07
    echo [RESULT] Value is NOT 1. (This would SHUTDOWN the PC)
)
pause

