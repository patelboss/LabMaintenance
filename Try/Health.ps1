# ==================================================
# [1] DIRECTORY & IDENTITY SETUP
# ==================================================
$BaseDir    = "C:\Lab_Maintenance"
$HealthDir  = "$BaseDir\Health"
$PCIDFile   = "$BaseDir\pc_id.txt"

# Ensure directories exist
if (-not (Test-Path $HealthDir)) { 
    New-Item -ItemType Directory -Path $HealthDir -Force | Out-Null 
}

# Identity Logic: Load or Create PC ID
if (Test-Path $PCIDFile) {
    $PCID = (Get-Content $PCIDFile).Trim()
} else {
    $PCID = Read-Host "Enter PC ID (e.g., 01, 05, 12)"
    $PCID | Out-File $PCIDFile
}

# ==================================================
# [2] THE "NO-COLLISION" STAGGERED START
# ==================================================
# Convert ID to a number and wait (ID 1 = 10s, ID 2 = 20s, etc.)
[int]$IDNum = $PCID
$WaitTime = $IDNum * 10 
Write-Host "PC-$PCID: Waiting $WaitTime seconds to prevent network jam..." -ForegroundColor Cyan
Start-Sleep -Seconds $WaitTime

# ==================================================
# [3] PROFESSIONAL DATA COLLECTION
# ==================================================
Write-Host "Gathering System Health..." -ForegroundColor Yellow

# Date/Time Objects
$DateRaw = Get-Date
$TS      = $DateRaw.ToString("ddMMyyyyHHmm")
$Month   = $DateRaw.ToString("MM-yyyy")

# Hardware Stats
$OS   = Get-CimInstance Win32_OperatingSystem
$RAM  = [math]::Round($OS.FreePhysicalMemory / 1024)
$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | 
        Select-Object @{n='FreeGB'; e={[math]::Round($_.FreeSpace / 1GB)}}

# Peripheral Audit (Keyboard & Mouse)
$Kbd = Get-PnpDevice -ClassName Keyboard -Status OK -ErrorAction SilentlyContinue
$Mse = Get-PnpDevice -ClassName Mouse,PointingDevice -Status OK -ErrorAction SilentlyContinue

$KbdStatus = if ($Kbd) { "OK" } else { "MISSING" }
$MseStatus = if ($Mse) { "OK" } else { "MISSING" }

# ==================================================
# [4] LOGGING (LOCAL FIRST)
# ==================================================
$LogPath = "$HealthDir\Health_PC$($PCID)_$($TS).txt"
$HealthData = @"
ID: $PCID
Timestamp: $TS
RAM Free: $($RAM) MB
Disk Free: $($Disk.FreeGB) GB
Keyboard: $KbdStatus
Mouse: $MseStatus
"@

$HealthData | Out-File $LogPath
Write-Host "Local Health Log Created: $LogPath" -ForegroundColor Green
