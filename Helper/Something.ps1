# ==================================================
# LAB MASTER DEPLOYMENT SCRIPT (MERGED VERSION)
# PowerShell 5.1 Compatible
# ==================================================

# ---------------- CONFIG ----------------

$AdminPC     = "PC-01"

$AdminUser   = "labadmin"
$AdminPass   = "Lab@12345"
$StudentUser = "student"

$SecurePass  = ConvertTo-SecureString $AdminPass -AsPlainText -Force

$BaseDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

$Icons    = Join-Path $BaseDir "Icons"
$LabData  = Join-Path $BaseDir "Lab_Data"
$Wallpaper= Join-Path $BaseDir "wallpaper.png"

$ProgDir  = "C:\Program Files\Lab_Data"
$WallDest = "C:\wallpaper.png"

$LogFile  = Join-Path $BaseDir "Setup_Log.txt"

# ---------------- LOGGER ----------------

function Write-Log {

    param(
        [string]$Message,
        [string]$Color = "White"
    )

    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-Host "[$Stamp] $Message" -ForegroundColor $Color
    "[$Stamp] $Message" | Out-File $LogFile -Append
}

# ==================================================
# STEP 1 : COPY FILES FIRST
# ==================================================

Write-Log "STEP 1 : Copying Lab Files..." "Cyan"

try {

    if (Test-Path $LabData) {

        if (!(Test-Path $ProgDir)) {
            New-Item $ProgDir -ItemType Directory | Out-Null
        }

        Copy-Item "$LabData\*" $ProgDir -Recurse -Force
        Write-Log "Lab Data copied" "Green"
    }

    if (Test-Path $Wallpaper) {

        Copy-Item $Wallpaper $WallDest -Force
        Write-Log "Wallpaper copied" "Green"
    }

}
catch {
    Write-Log "Copy error: $($_.Exception.Message)" "Red"
}

# ==================================================
# STEP 2 : CLEAN DESKTOP + DEPLOY ICONS
# ==================================================

Write-Log "STEP 2 : Cleaning Desktop..." "Cyan"

Remove-Item "$env:PUBLIC\Desktop\*" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\*" -Force -ErrorAction SilentlyContinue

if (Test-Path $Icons) {

    Copy-Item "$Icons\*" "$env:PUBLIC\Desktop\" -Recurse -Force
    Write-Log "Icons deployed" "Green"
}

# ==================================================
# STEP 3 : USER ACCOUNTS
# ==================================================

Write-Log "STEP 3 : Creating Users..." "Cyan"

if (-not (Get-LocalUser -Name $AdminUser -ErrorAction SilentlyContinue)) {

    New-LocalUser -Name $AdminUser -Password $SecurePass
    Add-LocalGroupMember Administrators $AdminUser
}

# Hide admin account

$HideKey = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"

if (!(Test-Path $HideKey)) {
    New-Item $HideKey -Force | Out-Null
}

Set-ItemProperty $HideKey $AdminUser 0 -Type DWord

# ==================================================
# STEP 4 : AUTO LOGIN FIX
# ==================================================

Write-Log "STEP 4 : Configuring AutoLogin..." "Cyan"

$Passwordless = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"

if (!(Test-Path $Passwordless)) {
    New-Item $Passwordless -Force
}

Set-ItemProperty $Passwordless DevicePasswordLessBuildVersion 0

$Winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# ==================================================
# STEP 5 : REMOTING CONFIG
# ==================================================

Write-Log "STEP 5 : Configuring PowerShell Remoting..." "Cyan"

Enable-PSRemoting -Force -SkipNetworkProfileCheck

Import-Module Microsoft.WSMan.Management

Set-Item WSMan:\localhost\Client\TrustedHosts -Value $AdminPC -Force

Set-ItemProperty `
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
LocalAccountTokenFilterPolicy 1

# ==================================================
# STEP 6 : NETWORK + SERVICES
# ==================================================

Write-Log "STEP 6 : Network Services..." "Cyan"

Get-NetConnectionProfile |
Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue

$Services = @(
"fdPHost",
"FDResPub",
"LanmanServer",
"LanmanWorkstation"
)

foreach ($Svc in $Services) {

    Set-Service $Svc -StartupType Automatic
    Start-Service $Svc -ErrorAction SilentlyContinue
}

netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

# ==================================================
# STEP 7 : SOFTWARE INSTALLATION
# ==================================================

Write-Log "STEP 7 : Installing Software..." "Cyan"

$Apps = @(

@{Name="Google Earth"; File="earth.exe"; Args="OMAHA=1"}
@{Name="QGIS"; File="QGIS.msi"; Args="/qn /norestart"}
@{Name="PeaZip"; File="peazip-10.9.0.WIN64.exe"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"}

)

foreach ($App in $Apps) {

    $File = Join-Path $BaseDir $App.File

    if (Test-Path $File) {

        Write-Log "Installing $($App.Name)" "Yellow"

        $Ext = [IO.Path]::GetExtension($File)

        if ($Ext -eq ".msi") {

            Start-Process msiexec.exe -ArgumentList "/i `"$File`" $($App.Args)" -Wait

        } else {

            Start-Process $File -ArgumentList $App.Args -Wait
        }

        Write-Log "$($App.Name) installed" "Green"
    }
}

# ==================================================
# FINAL
# ==================================================

Write-Log "=================================" "Cyan"
Write-Log "DEPLOYMENT COMPLETE" "Green"
Write-Log "Rebooting in 15 seconds..." "Red"

Start-Sleep 15
Restart-Computer -Force
