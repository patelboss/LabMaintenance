@echo off
setlocal EnableDelayedExpansion

:: Read PC ID
set /p PCID=<C:\LabMaintenance\pc_id.txt

:: Detect CPU cores
set CORES=%NUMBER_OF_PROCESSORS%
set /a LOAD=%CORES%/2
if %LOAD% LSS 1 set LOAD=1

:: Log start
echo ============================== >> C:\LabMaintenance\log.txt
echo PC: %PCID% >> C:\LabMaintenance\log.txt
echo Started: %date% %time% >> C:\LabMaintenance\log.txt
echo Cores: %CORES%  LoadThreads: %LOAD% >> C:\LabMaintenance\log.txt

:: CPU load
for /L %%A in (1,1,%LOAD%) do (
    start "" cmd /c "for /L %%B in () do rem"
)

:: Disk activity
for /L %%C in (1,1,5) do (
    fsutil file createnew C:\LabMaintenance\temp%%C.tmp 50000000
    del C:\LabMaintenance\temp%%C.tmp
)

:: Warm-up time (30 min)
timeout /t 1800 /nobreak

:: Stop load
taskkill /F /IM cmd.exe >nul 2>&1

:: Cool-down (10 min)
timeout /t 600 /nobreak

:: Log end
echo Finished: %date% %time% >> C:\LabMaintenance\log.txt

shutdown /s /t 0
