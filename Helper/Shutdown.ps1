$pcs = 1..40 | ForEach-Object { "PC-$($_.ToString('00'))" }

$pcs | ForEach-Object {
    Start-Job {
        shutdown /m \\$using:_ /s /f /t 0 /c "Lab shutdown"
    }
}
