@echo off
title Lab Maintenance Warm-Up

:: Log start
echo ============================== >> C:\LabMaintenance\log.txt
echo Started at %date% %time% >> C:\LabMaintenance\log.txt

:: -------- CPU LOAD (SAFE) --------
echo Running CPU warm-up...

for /L %%A in (1,1,4) do (
    start "" cmd /c "for /L %%B in () do rem"
)

:: -------- DISK ACTIVITY --------
echo Running disk activity...

for /L %%C in (1,1,5) do (
    fsutil file createnew C:\LabMaintenance\temp%%C.tmp 50000000
    del C:\LabMaintenance\temp%%C.tmp
)

:: -------- WARM-UP TIME --------
timeout /t 1800 /nobreak

:: -------- STOP LOAD --------
taskkill /F /IM cmd.exe >nul 2>&1

:: -------- COOL DOWN --------
timeout /t 600 /nobreak

:: Log shutdown
echo Shutdown at %date% %time% >> C:\LabMaintenance\log.txt

shutdown /s /t 0
