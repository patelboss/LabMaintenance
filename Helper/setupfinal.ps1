# ==================================================
# LAB MASTER SETUP - REMOTING-FIRST VERSION
# Optimized for PowerShell 5.1
# ==================================================

# --- CONFIGURATION ---
$AdminPC    = "PC-01"
$User       = "labadmin"
$Pass       = "Lab@12345"
$AdminUser   = "labadmin"
$AdminPass   = "Lab@12345"
$BASE    = $PSScriptRoot
$ICONS   = Join-Path $BASE "Icons"
$LABDATA = Join-Path $BASE "Lab_Data"
$WALLSRC = Join-Path $BASE "wallpaper.png"
$PROGDIR  = "C:\Program Files\Lab_Data"
$WALLDEST = "C:\wallpaper.png"
$SecurePass = ConvertTo-SecureString $Pass -AsPlainText -Force
$InstallDir = if ($PSScriptRoot) {
    $PSScriptRoot}
else {
    Split-Path -Parent $MyInvocation.MyCommand.Definition}
$LogFile = Join-Path $InstallDir "Lab_Repair_Log.txt"

#$LogFile = "$PSScriptRoot\Lab_Repair_Log.txt"

# ---------------- LOGGER ----------------

Function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-Host "[$Time] $Message" -ForegroundColor $Color
    "[$Time] $Message" | Out-File $LogFile -Append -Encoding UTF8
}

Write-Log "===== LAB STANDARDIZATION STARTED =====" "Cyan"
Write-Host "The computer name is: $env:COMPUTERNAME"


Write-Host ""
Write-Host "======================================"
Write-Host "   RUNNING LAB DEPLOYMENT"
Write-Host "======================================"

#==================================================

#CLEAN DESKTOP (Public and Current User)

#==================================================

Write-Host "[1/8] Cleaning Desktop Icons..."

Remove-Item "$env:PUBLIC\Desktop\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\*" -Recurse -Force -ErrorAction SilentlyContinue

#==================================================

#COPY ICONS

#==================================================

if (Test-Path $ICONS) {

Write-Host "[2/8] Deploying Lab Icons..."  

Copy-Item "$ICONS\*" "$env:PUBLIC\Desktop\" -Recurse -Force -ErrorAction SilentlyContinue

}

#==================================================

#COPY LAB DATA

#==================================================

if (Test-Path $LABDATA) {

Write-Host "[3/8] Copying Lab Data to Program Files..."  

if (!(Test-Path $PROGDIR)) {  
    New-Item -ItemType Directory -Path $PROGDIR | Out-Null  
}  

Copy-Item "$LABDATA\*" $PROGDIR -Recurse -Force -ErrorAction SilentlyContinue

}

#==================================================

#COPY WALLPAPER FILE ONLY
#==================================================

Write-Host "[7/8] Copying Wallpaper to C:..."

if (Test-Path $WALLSRC) {

Copy-Item $WALLSRC $WALLDEST -Force

}




# --------------------------------------------------
# STEP 1: ENABLE REMOTING & SIDELOADING
# --------------------------------------------------
Write-Log "STEP 1: Configuring Remoting & Sideloading..." "Cyan"

try {

    $DevKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"

    if (-not (Test-Path $DevKey)) {
        New-Item -Path $DevKey -Force | Out-Null
    }

    Set-ItemProperty $DevKey AllowAllTrustedApps 1 -Type DWord
    Set-ItemProperty $DevKey AllowDevelopmentWithoutDevLicense 1 -Type DWord


    if (-not (Get-LocalUser -Name $User -ErrorAction SilentlyContinue)) {

        New-LocalUser -Name $User -Password $SecurePass `
            -FullName "Lab Administrator" `
            -Description "Hidden Admin"

        Add-LocalGroupMember Administrators $User
        Set-LocalUser $User -PasswordNeverExpires $true
    }


    $HideKey = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"

    if (-not (Test-Path $HideKey)) {
        New-Item -Path $HideKey -Force | Out-Null
    }

    Set-ItemProperty $HideKey $User 0 -Type DWord


    Set-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        LocalAccountTokenFilterPolicy 1 `
        -Type DWord


    Get-NetConnectionProfile -ErrorAction SilentlyContinue |
        Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue


    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    Import-Module Microsoft.WSMan.Management -ErrorAction SilentlyContinue

    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $AdminPC -Force


    Write-Log "OK: Remoting and Sideloading configured" "Green"
}
catch {

    Write-Log "WARN STEP 1: $($_.Exception.Message)" "Yellow"
}

# --------------------------------------------------
# STEP 2: APP LIST
# --------------------------------------------------
$Apps = @(

    @{Name="VC Redist"; File="vc.exe"; Args="/S"}

    @{Name="Google Chrome"; File="chrome.exe"; Args="/silent /install"}
    @{Name="Net Speed"; File="netspeed.msixbundle"; Args=""}
    @{Name="ChatGPT"; File="gpt.msixbundle"; Args=""}
    @{Name="Firefox"; File="firefox.msix"; Args=""}
    

    @{Name="Klavaro"; File="klavaro.exe"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"}
    @{Name="LocalSend"; File="localsend.exe"; Args="/AllUsers /VERYSILENT"}
    @{Name="Notepad++"; File="npp.exe"; Args="/S"}
    @{Name="RapidTyping"; File="rapidtyping.exe"; Args="/S"}

    @{Name="Soni Typing"; File="soni.exe"; Args="/S"}
    @{Name="Sonma Typing"; File="sonma.exe"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /CLOSEAPPLICATIONS /qn MERGETASKS='!runapp'"}
    @{Name="Tipp10 Typing"; File="tipp10.exe"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"}
    @{Name="Telegram"; File="telegram.exe"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"}
    @{Name="Google Earth Pro"; File="earth.exe"; Args="OMAHA=1"}
    @{Name="Qgis"; File="QGIS.msi"; Args="/qn /norestart"}
    @{Name="PEAZIP"; File="peazip-10.9.0.WIN64.exe"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"}
)

# --------------------------------------------------
# STEP 3: PRE-CHECK
# --------------------------------------------------
Write-Log "STEP 2: Checking installation files..." "Cyan"

$MissingCount = 0

foreach ($App in $Apps) {
    if (-not (Test-Path (Join-Path $InstallDir $App.File))) {

        Write-Log "ERR: Missing $($App.File)" "Red"
        $MissingCount++
    }
}

if ($MissingCount -gt 0) {

    Write-Log "ABORTED: $MissingCount files missing" "Red"
    Read-Host "Press Enter to exit"
    Exit
}

# --------------------------------------------------
# STEP 4: INSTALL
# --------------------------------------------------
Write-Log "STEP 3: Installing Software..." "Cyan"

foreach ($App in $Apps) {

    $FilePath = Join-Path $InstallDir $App.File
    $Ext = [IO.Path]::GetExtension($FilePath).ToLower()

    Write-Log "Installing $($App.Name)" "Yellow"

    try {

        if ($Ext -match "appx|msix|bundle") {

            dism.exe /Online `
                /Add-ProvisionedAppxPackage `
                /PackagePath:"$FilePath" `
                /SkipLicense `
                /NoRestart
        }
        else {

            $Args = if ($Ext -eq ".msi") {
                "/i `"$FilePath`" $($App.Args) /qn /norestart"
            }
            else {
                $App.Args
            }

            $Cmd = if ($Ext -eq ".msi") { "msiexec.exe" } else { $FilePath }

            $Proc = Start-Process $Cmd -ArgumentList $Args -Wait -PassThru

            Write-Log "OK: $($App.Name) ExitCode $($Proc.ExitCode)" "Green"
        }
    }
    catch {

        Write-Log "ERR: $($App.Name) $($_.Exception.Message)" "Red"
    }
}








# ==================================================
# LAB STANDARDIZATION SCRIPT (NO INSTALLS)
# Admin + Sharing + Network Repair + Remoting
# Windows 10/11 | PowerShell 5.1+
# ==================================================

# ---------------- CONFIG ----------------

# ==================================================
# STEP 1: ADMIN USER
# ==================================================

Write-Log "Checking admin account..." "Cyan"

try {

    if (-not (Get-LocalUser -Name $AdminUser -ErrorAction SilentlyContinue)) {

        New-LocalUser `
            -Name $AdminUser `
            -Password $SecurePass `
            -Description "Hidden Lab Admin"

        Add-LocalGroupMember Administrators $AdminUser
        Set-LocalUser $AdminUser -PasswordNeverExpires $true

        Write-Log "Admin created" "Green"
    }
    else {

        Add-LocalGroupMember Administrators $AdminUser -ErrorAction SilentlyContinue
        Set-LocalUser $AdminUser -PasswordNeverExpires $true

        Write-Log "Admin verified" "Green"
    }

}
catch {
    Write-Log "Admin setup error: $($_.Exception.Message)" "Red"
}


# Hide admin from login screen
try {

    $HideKey = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"

    if (-not (Test-Path $HideKey)) {
        New-Item $HideKey -Force | Out-Null
    }

    Set-ItemProperty $HideKey $AdminUser 0 -Type DWord

    Write-Log "Admin hidden" "Green"
}
catch {
    Write-Log "Admin hide failed" "Yellow"
}


# ==================================================
# STEP 2: DISABLE AUTO-LOGIN (CLEANUP)
# ==================================================

Write-Log "Ensuring auto-login is disabled..." "Cyan"

try {
    $Winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    Set-ItemProperty $Winlogon "AutoAdminLogon" "0"
    Remove-ItemProperty $Winlogon "DefaultUserName" -ErrorAction SilentlyContinue
    Remove-ItemProperty $Winlogon "DefaultPassword" -ErrorAction SilentlyContinue

    Write-Log "Auto-login disabled" "Green"
}
catch {
    Write-Log "Auto-login cleanup failed" "Yellow"
}


# ==================================================
# STEP 3: SHARING POLICY
# ==================================================

Write-Log "Fixing sharing policy..." "Cyan"

try {

    Set-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        LocalAccountTokenFilterPolicy 1 `
        -Type DWord

    Write-Log "Sharing policy fixed" "Green"
}
catch {
    Write-Log "Sharing policy error" "Yellow"
}


# ==================================================
# STEP 4: NETWORK PROFILE
# ==================================================

Write-Log "Setting network to Private..." "Cyan"

try {

    Get-NetConnectionProfile -ErrorAction SilentlyContinue |
        Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue

    Write-Log "Network set to Private" "Green"
}
catch {
    Write-Log "Network profile error" "Yellow"
}


# ==================================================
# STEP 5: REQUIRED SERVICES
# ==================================================

Write-Log "Fixing services..." "Cyan"

$Services = @(
    "fdPHost",
    "FDResPub",
    "LanmanServer",
    "LanmanWorkstation",
    "SSDPSRV",
    "upnphost"
)

foreach ($Svc in $Services) {

    try {
        Set-Service $Svc -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service $Svc -ErrorAction SilentlyContinue
        Write-Log "Service OK: $Svc" "Green"
    }
    catch {
        Write-Log "Service issue: $Svc" "Yellow"
    }
}


# ==================================================
# STEP 6: FIREWALL RULES
# ==================================================

Write-Log "Enabling firewall rules..." "Cyan"

try {

    netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes | Out-Null
    netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes | Out-Null

    Write-Log "Firewall configured" "Green"
}
catch {
    Write-Log "Firewall error" "Yellow"
}


# ==================================================
# STEP 7: REMOTING
# ==================================================

Write-Log "Configuring remoting..." "Cyan"

try {

    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Import-Module Microsoft.WSMan.Management -ErrorAction SilentlyContinue
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $AdminPC -Force

    Write-Log "Remoting enabled" "Green"
}
catch {
    Write-Log "Remoting error" "Yellow"
}


# ==================================================
# STEP 8: NETWORK CACHE CLEAN
# ==================================================

Write-Log "Clearing network cache..." "Cyan"

try {

    ipconfig /flushdns | Out-Null
    nbtstat -RR | Out-Null

    Write-Log "Network cache cleared" "Green"
}
catch {
    Write-Log "Cache clean failed" "Yellow"
}



#My Command 
Write-Log "Running Your Commands" "Yellow" 

cd "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
ls

Get-ItemProperty . | Select-Object AutoAdminLogon, ForceAutoLogon, DefaultUserName


Start-Sleep 1

Remove-ItemProperty . -Name "DefaultUserName" -ErrorAction SilentlyContinue

Set-ItemProperty . -Name "ForceAutoLogon" -Value "0"

Set-ItemProperty . -Name "AutoAdminLogon" -Value "0"

Set-ItemProperty . -Name "DefaultUserName" -Value "Students" 


Get-ItemProperty . | Select-Object AutoAdminLogon, ForceAutoLogon, DefaultUserName

