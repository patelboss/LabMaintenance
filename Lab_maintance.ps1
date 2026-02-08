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
# Sequential delay based on ID to prevent network jams
[int]$IDNum = $PCID
$WaitTime = $IDNum * 10 
Write-Host "PC-$PCID: Waiting $WaitTime seconds for sequential clearance..." -ForegroundColor Cyan
Start-Sleep -Seconds $WaitTime

# ==================================================
# [3] PROFESSIONAL DATA COLLECTION (PWSH 7 FIX)
# ==================================================
Write-Host "Gathering System Health..." -ForegroundColor Yellow

$DateRaw = Get-Date
$TS      = $DateRaw.ToString("ddMMyyyyHHmm")

# Hardware Stats via CIM
$OS   = Get-CimInstance Win32_OperatingSystem
$RAM  = [math]::Round($OS.FreePhysicalMemory / 1024)
$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | 
        Select-Object @{n='FreeGB'; e={[math]::Round($_.FreeSpace / 1GB)}}

# Peripheral Audit
$AllPnp = Get-PnpDevice -Status OK -ErrorAction SilentlyContinue
$Kbd = $AllPnp | Where-Object { $_.FriendlyName -match "Keyboard" -or $_.Class -eq "Keyboard" }
$Mse = $AllPnp | Where-Object { $_.FriendlyName -match "Mouse" -or $_.Class -match "Mouse|PointingDevice" }

$KbdStatus = if ($Kbd) { "OK" } else { "MISSING" }
$MseStatus = if ($Mse) { "OK" } else { "MISSING" }

# Save Local Log
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

# ==================================================
# [4] SMART WARM-UP (50-60% DUTY CYCLE)
# ==================================================
# Clean slate: kill old jobs
Get-Job | Remove-Job -Force

$WarmupMinutes = 20 # Adjust per PC as planned
$TotalSeconds  = $WarmupMinutes * 60
$WorkerCount   = $env:NUMBER_OF_PROCESSORS

Write-Host "Starting $WorkerCount throttled workers (Target 50-60% CPU)..." -ForegroundColor Yellow

# Precision Duty Cycle Workers
$Jobs = for ($i=1; $i -le $WorkerCount; $i++) {
    Start-Job -ScriptBlock { 
        while($true) { 
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            while($sw.ElapsedMilliseconds -lt 50) { $null = 1 + 1 }
            $sw.Stop()
            Start-Sleep -Milliseconds 40 
        } 
    }
}

# ==================================================
# [5] COUNTDOWN & MONITORING
# ==================================================
$EndTime = (Get-Date).AddSeconds($TotalSeconds)

while ((Get-Date) -lt $EndTime) {
    $TimeLeft = $EndTime - (Get-Date)
    cls
    Write-Host "=================================================="
    Write-Host "   PC: $PCID  |  WARM-UP ACTIVE  |  $(Get-Date -Format HH:mm:ss)"
    Write-Host "=================================================="
    Write-Host "   REMAINING: $($TimeLeft.Minutes)m $($TimeLeft.Seconds)s"
    Write-Host "   TARGET LOAD: 50-60%"
    Write-Host "   KBD: $KbdStatus | MSE: $MseStatus"
    Write-Host "=================================================="
    Write-Host "   [!] PRESS 'Q' TO ABORT INTERACTIVELY"

    if ($Host.UI.RawUI.KeyAvailable) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($Key.Character -match 'q|Q') { break }
    }
    Start-Sleep -Seconds 1
}

# Cooldown
Write-Host "`nStopping workers..." -ForegroundColor Cyan
$Jobs | Stop-Job | Remove-Job -Force

# ==================================================
# [6] SYNC ENGINE (5x RETRY LOGIC)
# ==================================================
$AdminPath = "\\PC-01\c$\Users\window\All_PCs_Health\$PCID"
$Success = $false
$Retries = 0

while (-not $Success -and $Retries -lt 5) {
    if (Test-Connection -ComputerName "PC-01" -Count 1 -Quiet) {
        try {
            if (-not (Test-Path $AdminPath)) { New-Item $AdminPath -ItemType Directory -Force | Out-Null }
            Get-ChildItem $HealthDir -Filter "*.txt" | Copy-Item -Destination $AdminPath -Force -ErrorAction Stop
            $Success = $true
            Write-Host "Logs synced to Admin PC successfully." -ForegroundColor Green
        } catch { $Retries++; Start-Sleep -Seconds 30 }
    } else { $Retries++; Start-Sleep -Seconds 60 }
}

