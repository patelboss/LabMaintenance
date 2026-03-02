@echo off
powershell -ExecutionPolicy Bypass -File check-health.ps1
call cpu-maintenance.bat
exit /b
