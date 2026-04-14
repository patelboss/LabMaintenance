$sourcePath = "\\PC-01\Installer\*"      
$destinationPath = "C:\LocalFolder\"      

foreach ($pc in $pcs) {
    Write-Host "Processing $pc..." -ForegroundColor Cyan
    
    try {
        $session = New-PSSession -ComputerName $pc -ErrorAction Stop
        Invoke-Command -Session $session -ScriptBlock { 
            if (!(Test-Path $using:destinationPath)) { 
                Write-Host "Creating directory: $using:destinationPath"
                New-Item -ItemType Directory -Path $using:destinationPath -Force | Out-Null
            } 
        }

        Write-Host "Copying files to $pc..."
        Copy-Item -Path $sourcePath -Destination $destinationPath -ToSession $session -Recurse -Force
        
        # 4. Cleanup
        Remove-PSSession $session
        Write-Host "Successfully updated $pc" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to process $pc. Error: $_"
    }
}





# Assuming $pcs is already defined as your array of names/IPs
# $pcs = Get-Content "C:\path\to\your\list.txt"

$SourcePath = "C:\SourceFolder\cpu-maintenance"
$DestPath   = "C:\Program Files\Lab_data\cpu-maintenance"

foreach ($pc in $pcs) {
    Write-Host "Processing $pc..." -ForegroundColor Cyan
    
    try {
        # Establish a temporary session
        $session = New-PSSession -ComputerName $pc -ErrorAction Stop

        # Copy-Item handles the 'grab and send' logic.
        # -Force is used to overwrite the existing file.
        Copy-Item -Path $SourcePath `
                  -Destination $DestPath `
                  -ToSession $session `
                  -Force `
                  -ErrorAction Stop

        Write-Host "Successfully updated $pc" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to update $pc. Error: $($_.Exception.Message)"
        # Use 'break' here if you want the entire script to stop on the first error
        # break 
    }
    finally {
        # Clean up the session immediately to free up resources
        if ($session) {
            Remove-PSSession $session
        }
    }
}
