# ==================================================
# [0] CONFIGURATION
# ==================================================
$PCID = $env:COMPUTERNAME
$WarmupMinutes = 20
$TotalSeconds  = $WarmupMinutes * 60

$TargetMin       = 50
$TargetMax       = 60
$AdjustStep      = 5
$MonitorInterval = 3

Write-Host "[LIVE] Starting CPU Maintenance for $PCID..." -ForegroundColor Yellow

# ==================================================
# [1] CPU WARM-UP WORKERS
# ==================================================
Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue

# Shared workload values
$Global:WorkTime  = 40
$Global:SleepTime = 60

$Jobs = for ($i=1; $i -le $env:NUMBER_OF_PROCESSORS; $i++) {
    Start-Job -ScriptBlock {
        while ($true) {

            $wt = $using:WorkTime
            $st = $using:SleepTime

            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            while ($sw.ElapsedMilliseconds -lt $wt) { $null = 1 + 1 }
            $sw.Stop()

            Start-Sleep -Milliseconds $st
        }
    }
}

# ==================================================
# [2] MONITORING + DYNAMIC CONTROL LOOP
# ==================================================
$EndTime = (Get-Date).AddSeconds($TotalSeconds)

while ((Get-Date) -lt $EndTime) {

    $TimeLeft = $EndTime - (Get-Date)

    # Read CPU usage (lightweight)
    $Cpu = (Get-CimInstance Win32_Processor |
            Measure-Object -Property LoadPercentage -Average).Average

    # Adjust workload dynamically
    if ($Cpu -lt $TargetMin) {
        $Global:WorkTime += $AdjustStep
    }
    elseif ($Cpu -gt $TargetMax) {
        $Global:WorkTime -= $AdjustStep
    }

    # Clamp safety limits
    if ($Global:WorkTime -lt 10) { $Global:WorkTime = 10 }
    if ($Global:WorkTime -gt 90) { $Global:WorkTime = 90 }

    cls
    Write-Host "=================================================="
    Write-Host "   PC: $PCID  |  MAINTENANCE ACTIVE "
    Write-Host "=================================================="
    Write-Host "   CPU USAGE        : $([int]$Cpu)%"
    Write-Host "   TARGET RANGE     : $TargetMin - $TargetMax %"
    Write-Host "--------------------------------------------------"
    Write-Host "   WorkTime (ms)    : $Global:WorkTime"
    Write-Host "   SleepTime (ms)   : $Global:SleepTime"
    Write-Host "--------------------------------------------------"
    Write-Host "   TIME REMAINING   : $($TimeLeft.Minutes)m $($TimeLeft.Seconds)s"
    Write-Host "   Workers Running  : $($Jobs.Count)"
    Write-Host "--------------------------------------------------"
    Write-Host "   STATUS: Adaptive CPU Conditioning..."
    Write-Host "   Press 'Q' to abort maintenance."
    Write-Host "=================================================="

    # Abort support
    if ($Host.UI.RawUI.KeyAvailable) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($Key.Character -match 'q|Q') { break }
    }

    Start-Sleep -Seconds $MonitorInterval
}

# ==================================================
# [3] CLEANUP
# ==================================================
$Jobs | Stop-Job | Remove-Job -Force
Write-Host "[LIVE] Maintenance Complete." -ForegroundColor Green
