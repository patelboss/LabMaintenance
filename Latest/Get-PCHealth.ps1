# ==================================================
# [0] GLOBAL CONFIGURATION & IDENTITY
# ==================================================
$PCID      = $env:COMPUTERNAME
$AdminPC   = "PC-01"
$AdminRoot = "\\$AdminPC\All_PCs_Health"
$BaseDir   = "C:\Lab_Maintenance"
$HealthDir = "$BaseDir\Health"
$ErrorLog  = "$BaseDir\error.log"

if (-not (Test-Path $HealthDir)) { New-Item -ItemType Directory -Path $HealthDir -Force | Out-Null }

Write-Host "[LIVE] System Identity: $PCID" -ForegroundColor Green

# ==================================================
# [1] STAGGERED START (Based on PC Number)
# ==================================================
# Extracts digits from the PC Name (e.g., "LAB-PC05" -> 5)
$IDNum = [int]($PCID -replace "[^0-9]", "")
if (!$IDNum) { $IDNum = 1 } # Default if no numbers found
#
$WaitTime = $IDNum * 5

Write-Host "[LIVE] Staggering start for $WaitTime seconds..." -ForegroundColor Cyan
Start-Sleep -Seconds $WaitTime

# ==================================================
# [2] DATA COLLECTION
# ==================================================
Write-Host "[LIVE] Auditing Hardware..." -ForegroundColor Yellow
$TS = (Get-Date).ToString("ddMMyyyyHHmm")

$OS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$RAM = if ($OS) { [math]::Round($OS.FreePhysicalMemory / 1024) } else { "N/A" }

$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
$DiskFree = if ($Disk) { [math]::Round($Disk.FreeSpace / 1GB) } else { "N/A" }

$AllPnp = Get-PnpDevice -Status OK -ErrorAction SilentlyContinue
$KbdStatus = if ($AllPnp | Where-Object { $_.FriendlyName -match "Keyboard" }) { "OK" } else { "MISSING" }
$MseStatus = if ($AllPnp | Where-Object { $_.FriendlyName -match "Mouse|Pointing" }) { "OK" } else { "MISSING" }

# Save Local Log
$LogPath = "$HealthDir\Health_$($PCID)_$($TS).txt"
$HealthData = "ID: $PCID`nTimestamp: $TS`nRAM Free: $RAM MB`nDisk Free: $DiskFree GB`nKBD: $KbdStatus`nMSE: $MseStatus"
$HealthData | Out-File $LogPath

# ==================================================
# [3] SYNC TO ADMIN
# ==================================================
Write-Host "[LIVE] Syncing with Admin PC..." -ForegroundColor Cyan
$AdminPath = "$AdminRoot\$PCID"
if (Test-Connection -ComputerName $AdminPC -Count 1 -Quiet) {
    try {
        if (-not (Test-Path $AdminPath)) { New-Item $AdminPath -ItemType Directory -Force | Out-Null }
        Get-ChildItem $HealthDir -Filter "*.txt" | Copy-Item -Destination $AdminPath -Force
        Write-Host "[LIVE] Sync Successful!" -ForegroundColor Green
    } catch { 
        "$(Get-Date): Sync Error" | Out-File $ErrorLog -Append 
    }
}

