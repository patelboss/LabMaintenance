# ==================================================
# [0] CONFIGURATION
# ==================================================
$PCID = $env:COMPUTERNAME
$WarmupMinutes = 20 
$TotalSeconds  = $WarmupMinutes * 60

Write-Host "[LIVE] Starting CPU Maintenance for $PCID..." -ForegroundColor Yellow

# ==================================================
# [1] CPU WARM-UP WORKERS
# ==================================================
Get-Job | Remove-Job -Force
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
    Write-Host "   PC: $PCID  |  MAINTENANCE ACTIVE "
    Write-Host "=================================================="
    Write-Host "   TIME REMAINING: $($TimeLeft.Minutes)m $($TimeLeft.Seconds)s"
    Write-Host "   STATUS: Stressing CPU for stability..."
    Write-Host "   Press 'Q' to abort maintenance."
    Write-Host "=================================================="

    if ($Host.UI.RawUI.KeyAvailable) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($Key.Character -match 'q|Q') { break }
    }
    Start-Sleep -Seconds 1
}

$Jobs | Stop-Job | Remove-Job -Force
Write-Host "[LIVE] Maintenance Complete." -ForegroundColor Green

