@echo off
echo Setting up Lab Maintenance...

:: Create weekly warm-up task
schtasks /create /f ^
 /sc weekly ^
 /d SUN ^
 /st 10:00 ^
 /tn "Lab_Warmup" ^
 /tr "C:\LabMaintenance\warmup.bat" ^
 /ru SYSTEM ^
 /rl highest

:: Create monthly report task
schtasks /create /f ^
 /sc monthly ^
 /d 1 ^
 /st 09:00 ^
 /tn "Lab_Monthly_Report" ^
 /tr "C:\LabMaintenance\report.bat" ^
 /ru SYSTEM ^
 /rl highest

echo Setup completed successfully.
pause
