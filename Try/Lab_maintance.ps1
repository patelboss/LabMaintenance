# ==================================================
# [0] GLOBAL CONFIGURATION
# ==================================================
$AdminPC   = "PC-01"
$AdminRoot = "\\$AdminPC\c$\Users\window\All_PCs_Health"
$BaseDir   = "C:\Lab_Maintenance"
$HealthDir = "$BaseDir\Health"
$PCIDFile  = "$BaseDir\pc_id.txt"
$ErrorLog  = "$BaseDir\error.log"

# ==================================================
# [1] IDENTITY SETUP (SUPPORT FOR PC_02)
# ==================================================
Write-Host "[LIVE] Checking System Identity..." -ForegroundColor Gray
if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null }

if (Test-Path $PCIDFile) {
    $PCID = (Get-Content $PCIDFile).Trim()
    Write-Host "[LIVE] Identity Found: $PCID" -ForegroundColor Green
} else {
    do {
        # Validates for PC_02 format specifically
        $PCID = Read-Host "Enter PC ID (Format: PC_01, PC_02)"
    } until ($PCID -match '^PC_\d{2}$')
    $PCID | Out-File $PCIDFile
    Write-Host "[LIVE] Identity Created: $PCID" -ForegroundColor Green
}

# ==================================================
# [2] THE "NO-COLLISION" STAGGERED START
# ==================================================
# Strips the "PC_" to calculate wait time accurately
$NumericPart = $PCID -replace "PC_", ""
[int]$IDNum = $NumericPart
$WaitTime = $IDNum * 10 

Write-Host "[LIVE] Staggering start for $WaitTime seconds to prevent network jam..." -ForegroundColor Cyan
Start-Sleep -Seconds $WaitTime

# ==================================================
# [3] DATA COLLECTION (ROBUST & LIVE)
# ==================================================
Write-Host "[LIVE] Auditing Hardware..." -ForegroundColor Yellow
$TS = (Get-Date).ToString("ddMMyyyyHHmm")

$OS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$RAM = if ($OS) { [math]::Round($OS.FreePhysicalMemory / 1024) } else { "N/A" }
Write-Host "[LIVE] RAM Checked: $RAM MB Free" -ForegroundColor Gray

$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
$DiskFree = if ($Disk) { [math]::Round($Disk.FreeSpace / 1GB) } else { "N/A" }
Write-Host "[LIVE] Disk Checked: $DiskFree GB Free" -ForegroundColor Gray

$AllPnp = Get-PnpDevice -Status OK -ErrorAction SilentlyContinue
$Kbd = $AllPnp | Where-Object { $_.FriendlyName -match "Keyboard" -or $_.Class -eq "Keyboard" }
$Mse = $AllPnp | Where-Object { $_.FriendlyName -match "Mouse" -or $_.Class -match "Mouse|PointingDevice" }

$KbdStatus = if ($Kbd) { "OK" } else { "MISSING" }
$MseStatus = if ($Mse) { "OK" } else { "MISSING" }
Write-Host "[LIVE] Peripherals: KBD($KbdStatus) MSE($MseStatus)" -ForegroundColor Gray

$LogPath = "$HealthDir\Health_$($PCID)_$($TS).txt"
$HealthData = "ID: $PCID`nTimestamp: $TS`nRAM Free: $RAM MB`nDisk Free: $DiskFree GB`nKBD: $KbdStatus`nMSE: $MseStatus"
$HealthData | Out-File $LogPath
Write-Host "[LIVE] Local Log Saved: $LogPath" -ForegroundColor Green

# ==================================================
# [4] SMART WARM-UP (THROTTLED)
# ==================================================
Write-Host "[LIVE] Launching CPU Warm-up Workers..." -ForegroundColor Yellow
Get-Job | Remove-Job -Force
$WarmupMinutes = 20 
$TotalSeconds  = $WarmupMinutes * 60

$Jobs = for ($i=1; $i -le $env:NUMBER_OF_PROCESSORS; $i++) {
    Start-Job -ArgumentList $TotalSeconds -ScriptBlock { 
        param($Secs)
        $EndJob = (Get-Date).AddSeconds($Secs)
        while((Get-Date) -lt $EndJob) { 
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            while($sw.ElapsedMilliseconds -lt 50) { $null = 1 + 1 }
            $sw.Stop()
            Start-Sleep -Milliseconds 40 
        } 
    }
}

# Monitoring Loop
$EndTime = (Get-Date).AddSeconds($TotalSeconds)
while ((Get-Date) -lt $EndTime) {
    $TimeLeft = $EndTime - (Get-Date)
    cls
    Write-Host "=================================================="
    Write-Host "   PC: $PCID  |  WARM-UP ACTIVE  |  $(Get-Date -Format HH:mm:ss)"
    Write-Host "=================================================="
    Write-Host "   REMAINING: $($TimeLeft.Minutes)m $($TimeLeft.Seconds)s"
    Write-Host "   KBD: $KbdStatus | MSE: $MseStatus"
    Write-Host "   STATUS: System Conditioning in Progress..."
    Write-Host "=================================================="

    if ($Host.UI.RawUI.KeyAvailable) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($Key.Character -match 'q|Q') { 
            $Jobs | Stop-Job | Remove-Job -Force 
            Write-Host "[LIVE] Aborted by User Request." -ForegroundColor Red
            break 
        }
    }
    Start-Sleep -Seconds 1
}

$Jobs | Stop-Job | Remove-Job -Force
Write-Host "[LIVE] Warm-up Complete. Workers Stopped." -ForegroundColor Green

# ==================================================
# [5] SYNC ENGINE (LIVE REPORTING)
# ==================================================
Write-Host "[LIVE] Attempting to Sync with Admin PC ($AdminPC)..." -ForegroundColor Cyan
$AdminPath = "$AdminRoot\$PCID"
$Success = $false
$Retries = 0

while (-not $Success -and $Retries -lt 5) {
    if (Test-Connection -ComputerName $AdminPC -Count 1 -Quiet) {
        try {
            if (-not (Test-Path $AdminPath)) { New-Item $AdminPath -ItemType Directory -Force | Out-Null }
            
            Get-ChildItem $HealthDir -Filter "*.txt" | 
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-2) } |
                Copy-Item -Destination $AdminPath -Force -ErrorAction Stop
            
            $Success = $true
            Write-Host "[LIVE] Sync Successful! Reports sent to Admin PC." -ForegroundColor Green
        } catch { 
            Write-Host "[LIVE] Sync Failed (Attempt $($Retries+1)). Folder may be locked." -ForegroundColor Red
            "$(Get-Date): Sync Error - $($_.Exception.Message)" | Out-File $ErrorLog -Append
            $Retries++; Start-Sleep -Seconds 30 
        }
    } else { 
        Write-Host "[LIVE] Admin PC is Offline. Waiting to retry..." -ForegroundColor Red
        "$(Get-Date): Admin PC Offline" | Out-File $ErrorLog -Append
        $Retries++; Start-Sleep -Seconds 60 
    }
}

Write-Host "[LIVE] Maintenance Session Finished." -ForegroundColor Green
# Stop-Computer -Force
