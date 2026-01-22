@echo off
title CMD Diagnostic Test

echo ===============================
echo   CMD DIAGNOSTIC SCRIPT
echo ===============================
echo If you see this text, CMD opened.
echo.

pause

set BASEDIR=%~dp0TestData
set LOGFILE=%BASEDIR%\test.log

echo Creating folder: %BASEDIR%
mkdir "%BASEDIR%" 2>nul

echo Writing log file...
echo Test log created at %date% %time% > "%LOGFILE%"

if exist "%LOGFILE%" (
    echo SUCCESS: Log file created.
) else (
    echo FAILURE: Log file NOT created.
)

echo.
echo Check the folder:
echo %BASEDIR%
echo.

pause
