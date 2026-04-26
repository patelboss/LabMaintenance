# ==================================================
# [0] GLOBAL CONFIGURATION
# ==================================================
$PCID      = $env:COMPUTERNAME
$AdminPC   = "PC-01"
$AdminRoot = "\\$AdminPC\All_PCs_Health"
$BaseDir   = "C:\Lab_Maintenance"
$HealthDir = "$BaseDir\Health"
$ErrorLog  = "$BaseDir\error.log"

if (-not (Test-Path $HealthDir)) {
    New-Item -ItemType Directory -Path $HealthDir -Force | Out-Null
}

Write-Host "[LIVE] System Identity: $PCID" -ForegroundColor Green
# ==================================================
# [1] STAGGER START
# ==================================================
$IDNum = [int]($PCID -replace "[^0-9]", "")
if (!$IDNum) { $IDNum = 1 }

$WaitTime = $IDNum * 5
Write-Host "[LIVE] Staggering start for $WaitTime seconds..." -ForegroundColor Cyan
Start-Sleep -Seconds $WaitTime

# ==================================================
# [2] DATA COLLECTION
# ==================================================
Write-Host "[LIVE] Collecting Health Data..." -ForegroundColor Yellow
#old $TS = (Get-Date).ToString("ddMMyyyyHHmm")

$TS = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$OS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$RAM = if ($OS) { [math]::Round($OS.FreePhysicalMemory / 1024) } else { "NA" }

$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
$DiskFree = if ($Disk) { [math]::Round($Disk.FreeSpace / 1GB) } else { "NA" }

$AllPnp = Get-PnpDevice -Status OK -ErrorAction SilentlyContinue
$KbdStatus = if ($AllPnp | Where-Object { $_.FriendlyName -match "Keyboard" }) { "OK" } else { "MISSING" }
$MseStatus = if ($AllPnp | Where-Object { $_.FriendlyName -match "Mouse|Pointing" }) { "OK" } else { "MISSING" }
#$HealthData | Out-File $LogPath

# ==================================================
# [3] LOCAL CSV LOG (APPEND)
# ==================================================
$CsvPath = "$HealthDir\Health_$PCID.csv"

if (-not (Test-Path $CsvPath)) {
    "Timestamp,PCID,RAM_MB,Disk_GB,Keyboard,Mouse" | Out-File $CsvPath
}

"$TS,$PCID,$RAM,$DiskFree,$KbdStatus,$MseStatus" | Out-File $CsvPath -Append
# ==================================================
# [4] SYNC (BEST EFFORT)
# ==================================================
Write-Host "[LIVE] Syncing with Admin PC..." -ForegroundColor Cyan

$AdminPath = "$AdminRoot\$PCID"

if (Test-Connection -ComputerName $AdminPC -Count 1 -Quiet) {
    try {
        if (-not (Test-Path $AdminPath)) {
            New-Item $AdminPath -ItemType Directory -Force | Out-Null
        }

        Copy-Item $CsvPath -Destination $AdminPath -Force
        Write-Host "[LIVE] Sync Successful!" -ForegroundColor Green

    } catch {
        "$(Get-Date): Sync Error on $PCID" | Out-File $ErrorLog -Append
    }
}
