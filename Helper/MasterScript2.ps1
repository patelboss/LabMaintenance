function Read-ChoiceWithTimeout {
    param(
        [string]$Prompt,
        [int]$TimeoutSeconds = 15,
        [string]$Default = ""
    )

    Write-Host $Prompt -NoNewline -ForegroundColor Yellow
    Write-Host " [$TimeoutSeconds sec]: " -NoNewline -ForegroundColor DarkGray

    $input = ""
    $endTime = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $endTime) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                'Enter' {
                    if ([string]::IsNullOrWhiteSpace($input)) {
                        return $Default
                    }

                    return $input.Trim()
                }

                'Backspace' {
                    if ($input.Length -gt 0) {
                        $input = $input.Substring(0, $input.Length - 1)
                        Write-Host "`b `b" -NoNewline
                    }
                }

                default {
                    if ($key.KeyChar -ne [char]0) {
                        $input += $key.KeyChar
                        Write-Host $key.KeyChar -NoNewline
                    }
                }
            }
        }
        else {
            Start-Sleep -Milliseconds 100
        }
    }

    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($input)) {
        return $Default
    }

    return $input.Trim()
}

function Read-YesNoWithTimeout {
    param(
        [string]$Prompt,
        [int]$TimeoutSeconds = 15,
        [string]$Default = "N"
    )

    $result = Read-ChoiceWithTimeout -Prompt $Prompt -TimeoutSeconds $TimeoutSeconds -Default $Default
    if ([string]::IsNullOrWhiteSpace($result)) {
        return $Default.ToUpper()
    }

    return $result.ToUpper()
}

Clear-Host
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "         LAB ADMINISTRATOR TOOLKIT        " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "This tool works with the PC list stored in:" -ForegroundColor Cyan
Write-Host "C:\Desktop\pc_list.txt"
Write-Host ""
Write-Host "Choose what you want to do:" -ForegroundColor Cyan
Write-Host " 1) Copy File To All PC"
Write-Host " 2) Get File From All PC at same dir"
Write-Host " 3) Shutdown All Computers"
Write-Host " 4) Restart All Computers"
Write-Host " 5) Start Maintainance (future use)"
Write-Host " 0) Exit"
Write-Host ""
Write-Host "Tip: If you do nothing, the menu will time out and exit." -ForegroundColor DarkGray
Write-Host ""

$pcListPath = "C:\Desktop\pc_list.txt"
if (-not (Test-Path $pcListPath)) {
    Write-Warning "PC list file not found: $pcListPath"
    return
}

$pcs = Get-Content $pcListPath

while ($true) {
    Write-Host ""
    $choice = Read-ChoiceWithTimeout -Prompt "Enter your choice (0-5)" -TimeoutSeconds 20 -Default "0"

    switch ($choice) {
        "1" {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Yellow
            Write-Host " Remote File Copy (Admin -> Client PCs)" -ForegroundColor Yellow
            Write-Host "==========================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "This script will:" -ForegroundColor Cyan
            Write-Host " • Copy a file/folder from this PC to all client PCs."
            Write-Host " • Overwrite existing files if they already exist."
            Write-Host " • Process each computer one by one."
            Write-Host ""
            Write-Host "What to enter:" -ForegroundColor Cyan
            Write-Host " • Source path: file/folder on this PC"
            Write-Host " • Destination path: location on client PCs"
            Write-Host ""

            $SourcePath = Read-Host "Enter the source file/folder path on this PC"
            $DestPath = Read-Host "Enter the destination path on client PCs"

            foreach ($pc in $pcs) {
                Write-Host "Processing $pc..." -ForegroundColor Cyan
                $session = $null

                try {
                    $session = New-PSSession -ComputerName $pc -ErrorAction Stop

                    Copy-Item -Path $SourcePath `
                        -Destination $DestPath `
                        -ToSession $session `
                        -Force `
                        -ErrorAction Stop

                    Write-Host "Successfully updated $pc" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to update $pc. Error: $($_.Exception.Message)"
                }
                finally {
                    if ($session) {
                        Remove-PSSession $session
                    }
                }
            }

            Write-Host ""
            Write-Host "Process completed." -ForegroundColor Green
            Read-Host "Press Enter to return to menu"
            Clear-Host
        }

        "2" {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Yellow
            Write-Host " Remote File Collect (Client PCs -> Admin)" -ForegroundColor Yellow
            Write-Host "==========================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "This script will:" -ForegroundColor Cyan
            Write-Host " • Copy a file/folder from all client PCs to this PC."
            Write-Host " • Create one folder per PC under the destination root."
            Write-Host " • Process each computer one by one."
            Write-Host ""
            Write-Host "What to enter:" -ForegroundColor Cyan
            Write-Host " • Source path: file/folder on client PCs"
            Write-Host " • Destination folder: root folder on this PC"
            Write-Host ""

            $SourcePath = Read-Host "Enter the source path on client PCs"
            $DestPath = Read-Host "Enter the destination folder on this PC"

            foreach ($pc in $pcs) {
                Write-Host "Processing $pc..." -ForegroundColor Cyan
                $session = $null

                try {
                    $session = New-PSSession -ComputerName $pc -ErrorAction Stop

                    $LocalDest = Join-Path $DestPath $pc
                    if (-not (Test-Path $LocalDest)) {
                        New-Item -ItemType Directory -Path $LocalDest -Force | Out-Null
                    }

                    Copy-Item -FromSession $session `
                        -Path $SourcePath `
                        -Destination $LocalDest `
                        -Recurse `
                        -Force `
                        -ErrorAction Stop

                    Write-Host "Successfully collected from $pc" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to collect from $pc. Error: $($_.Exception.Message)"
                }
                finally {
                    if ($session) {
                        Remove-PSSession $session
                    }
                }
            }

            Write-Host ""
            Write-Host "Process completed." -ForegroundColor Green
            Read-Host "Press Enter to return to menu"
            Clear-Host
        }

        "3" {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Red
            Write-Host "              SHUTDOWN MODE               " -ForegroundColor Red
            Write-Host "==========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "WARNING: This will shut down ALL computers in the list." -ForegroundColor Yellow
            Write-Host "This action is immediate." -ForegroundColor Yellow
            Write-Host ""

            $confirm = Read-YesNoWithTimeout -Prompt "Type YES to continue, or press Enter to cancel" -TimeoutSeconds 15 -Default "N"

            if ($confirm -eq "YES") {
                Invoke-Command -ComputerName $pcs -ScriptBlock {
                    Stop-Computer -Force
                }
                Write-Host "Shutdown command sent to all computers." -ForegroundColor Green
            }
            else {
                Write-Host "Shutdown cancelled." -ForegroundColor Cyan
            }

            Read-Host "Press Enter to return to menu"
            Clear-Host
        }

        "4" {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Red
            Write-Host "               RESTART MODE               " -ForegroundColor Red
            Write-Host "==========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "WARNING: This will restart ALL computers in the list." -ForegroundColor Yellow
            Write-Host "This action is immediate." -ForegroundColor Yellow
            Write-Host ""

            $confirm = Read-YesNoWithTimeout -Prompt "Type YES to continue, or press Enter to cancel" -TimeoutSeconds 15 -Default "N"

            if ($confirm -eq "YES") {
                Invoke-Command -ComputerName $pcs -ScriptBlock {
                    Restart-Computer -Force
                }
                Write-Host "Restart command sent to all computers." -ForegroundColor Green
            }
            else {
                Write-Host "Restart cancelled." -ForegroundColor Cyan
            }

            Read-Host "Press Enter to return to menu"
            Clear-Host
        }

        "5" {
            Clear-Host

            Write-Host "==========================================" -ForegroundColor Yellow
            Write-Host "           MAINTENANCE MODULE             " -ForegroundColor Yellow
            Write-Host "==========================================" -ForegroundColor Yellow
            Write-Host ""

            Write-Host "Starting maintenance on all PCs..." -ForegroundColor Cyan
            Write-Host ""

            $mn = foreach ($pc in $pcs) {

                Write-Host "Starting maintenance on $pc..." -ForegroundColor Cyan

                Invoke-Command -ComputerName $pc -AsJob -JobName "Maint_$pc" -ScriptBlock {
                    & cmd.exe /c "C:\Program Files\Lab_Data\maintainance.bat" 2>&1
                }
            }

            $mn | Export-Csv -Path "C:\Users\labadmin\Desktop\Log_Document (3).csv" -NoTypeInformation

            Write-Host ""
            Write-Host "Maintenance jobs started." -ForegroundColor Green
            Write-Host ""

            $mn

            Write-Host ""
            Write-Host "Current maintenance jobs:" -ForegroundColor Yellow
            Write-Host ""

            Get-Job Maint_PC-*

            Write-Host ""
            Write-Host "Job information exported to:" -ForegroundColor Cyan
            Write-Host "C:\Users\labadmin\Desktop\Log_Document (3).csv"
            Write-Host ""

            Read-Host "Press Enter to return to menu"
            Clear-Host
        }

        "0" {
            Write-Host ""
            Write-Host "Exiting..." -ForegroundColor Cyan
            break
        }

        default {
            Write-Warning "Invalid choice. Enter a number from 0 to 5."
        }
    }
}
