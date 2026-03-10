$pcs = 1..40 | ForEach-Object { "PC-$($_.ToString('00'))" }

Invoke-Command -ComputerName $pcs -ScriptBlock {
    Stop-Computer -Force
} -ThrottleLimit 10 -ErrorAction SilentlyContinue -TimeoutSec 20
