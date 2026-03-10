$TargetPCs = Get-Content "C:\Users\labadmin\Lab_Data\PC_Id.txt"
foreach ($pc in $TargetPCs) {
    Write-Host "Processing $pc..." -ForegroundColor Cyan
    
    # 1. Create the Temp folder on the Remote PC
    $remoteTemp = "\\$pc\C$\Temp\LayoutFix"
    if (!(Test-Path $remoteTemp)) { 
        New-Item -ItemType Directory -Path $remoteTemp -Force | Out-Null 
    }
    
    # 2. Copy EVERYTHING from your Master folder to the Remote PC
    # This includes CL1-3, the .exe, the .dok, and the wallpaper
    Copy-Item "D:\inst\*" $remoteTemp -Recurse -Force

    # 3. Execute the commands INSIDE the Remote PC
    Invoke-Command -ComputerName $pc -ScriptBlock {
        $PublicDesktop = "C:\Users\Public\Desktop"
        $LocalTemp = "C:\Temp\LayoutFix"

        # Copy the 15 shortcuts to Public Desktop
        # We use -Recurse to grab files inside CL1, CL2, CL3
        Get-ChildItem -Path "$LocalTemp\CL*" | Copy-Item -Destination $PublicDesktop -Force

        # Set Wallpaper (Registry Change)
        $wallPath = "$LocalTemp\img.png"
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $wallPath
        # Force the wallpaper to update immediately
        rundll32.exe user32.dll,UpdatePerUserSystemParameters

        # THE GRID FIX: Run DesktopOK Silently
        # /load: tells it to restore a layout
        # /silent: tells it not to show a window
        $exePath = "$LocalTemp\DesktopOK_x64.exe"
        $dokPath = "$LocalTemp\layout.dok"
        
        if (Test-Path $exePath) {
            Start-Process -FilePath $exePath -ArgumentList "/load", "/silent", "$dokPath" -Wait
        }
    }
    Write-Host "Success: $pc is now configured!" -ForegroundColor Green
}

