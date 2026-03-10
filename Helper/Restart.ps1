$pcs = 1..40 | ForEach-Object { "PC-$($_.ToString('00'))" }


Invoke-Command -ComputerName $pcs { Restart-Computer -Force }
