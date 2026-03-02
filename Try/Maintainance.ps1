# ============================================================
# VERBOSE DYNAMIC CPU CONDITIONER (FULL MONITOR MODE)
# Target: 50-60% CPU
# ============================================================

# ---------------- SETTINGS ----------------
$DurationSeconds = 120
$TargetMin       = 50
$TargetMax       = 60
$AdjustStep      = 5
$MonitorInterval = 3
# ------------------------------------------

Clear-Host
Write-Host "========== INITIALIZING ==========" -ForegroundColor Cyan
Write-Host "Start Time        : $(Get-Date)"
Write-Host "Duration (sec)    : $DurationSeconds"
Write-Host "Target Range      : $TargetMin - $TargetMax %"
Write-Host "Adjust Step       : $AdjustStep ms"
Write-Host "Monitor Interval  : $MonitorInterval sec"
Write-Host "Logical CPUs      : $env:NUMBER_OF_PROCESSORS"
Write-Host "==================================="

$EndTime = (Get-Date).AddSeconds($DurationSeconds)

# Shared workload
$Global:WorkTime  = 40
$Global:SleepTime = 60

Write-Host "`n[INFO] Removing previous jobs..."
Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue

Write-Host "[INFO] Spawning Worker Jobs..."

$Jobs = for ($i=1; $i -le $env:NUMBER_OF_PROCESSORS; $i++) {
    Write-Host " -> Starting Worker $i"
    Start-Job -ScriptBlock {
        while ($true) {
            $wt = $using:WorkTime
            $st = $using:SleepTime

            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.ElapsedMilliseconds -lt $wt) { $null = 1 + 1 }
            $sw.Stop()

            Start-Sleep -Milliseconds $st
        }
    }
}

Write-Host "[INFO] $($Jobs.Count) Workers Started Successfully."
Write-Host "==============================================="
Write-Host ""

$Iteration = 0

# ---------------- CONTROLLER LOOP ----------------
while ((Get-Date) -lt $EndTime) {

    $Iteration++
    Start-Sleep -Seconds $MonitorInterval

    $Now = Get-Date
    $Remaining = [int]($EndTime - $Now).TotalSeconds

    # CPU Reading
    $CpuRaw = Get-CimInstance Win32_Processor
    $Cpu = ($CpuRaw | Measure-Object -Property LoadPercentage -Average).Average

    $OldWork = $Global:WorkTime
    $AdjustmentReason = "STABLE"

    if ($Cpu -lt $TargetMin) {
        $Global:WorkTime += $AdjustStep
        $AdjustmentReason = "LOW CPU → Increasing WorkTime"
    }
    elseif ($Cpu -gt $TargetMax) {
        $Global:WorkTime -= $AdjustStep
        $AdjustmentReason = "HIGH CPU → Decreasing WorkTime"
    }

    # Clamp limits
    if ($Global:WorkTime -lt 10) { $Global:WorkTime = 10 }
    if ($Global:WorkTime -gt 90) { $Global:WorkTime = 90 }

    # Job status
    $RunningJobs = ($Jobs | Where-Object { $_.State -eq "Running" }).Count

    # Memory snapshot
    $Mem = (Get-Process -Id $PID).WorkingSet64 / 1MB

    Clear-Host
    Write-Host "======================================================="
    Write-Host "            VERBOSE CPU CONDITIONING DASHBOARD"
    Write-Host "======================================================="
    Write-Host "Current Time          : $Now"
    Write-Host "Remaining Seconds     : $Remaining"
    Write-Host "Iteration Count       : $Iteration"
    Write-Host "-------------------------------------------------------"
    Write-Host "CPU Raw Instances     : $($CpuRaw.Count)"
    Write-Host "CPU Usage (%)         : $([int]$Cpu)"
    Write-Host "Target Range          : $TargetMin - $TargetMax"
    Write-Host "Adjustment Reason     : $AdjustmentReason"
    Write-Host "-------------------------------------------------------"
    Write-Host "Old WorkTime (ms)     : $OldWork"
    Write-Host "New WorkTime (ms)     : $Global:WorkTime"
    Write-Host "SleepTime (ms)        : $Global:SleepTime"
    Write-Host "-------------------------------------------------------"
    Write-Host "Logical CPUs          : $env:NUMBER_OF_PROCESSORS"
    Write-Host "Worker Jobs Created   : $($Jobs.Count)"
    Write-Host "Worker Jobs Running   : $RunningJobs"
    Write-Host "-------------------------------------------------------"
    Write-Host "PowerShell PID        : $PID"
    Write-Host "Memory Usage (MB)     : $([int]$Mem)"
    Write-Host "-------------------------------------------------------"
    Write-Host "Monitor Interval      : $MonitorInterval sec"
    Write-Host "Adjust Step           : $AdjustStep ms"
    Write-Host "======================================================="
}

Write-Host "`n[INFO] Stopping Worker Jobs..."
$Jobs | Stop-Job | Remove-Job -Force

Write-Host "[COMPLETE] Conditioning Finished Successfully." -ForegroundColor Green
Write-Host "End Time: $(Get-Date)"
