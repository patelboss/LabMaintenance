$pcs = Get-Content "C:\Scripts\pcs.txt"

$softwareLocation = "\\fileserver\software"

Invoke-Command -ComputerName $pcs -ScriptBlock {

    param($softwareLocation)

    $earthInstaller = Join-Path $softwareLocation "earth.exe"
    $qgisInstaller  = Join-Path $softwareLocation "QGIS.msi"

    # Install QGIS
    if (Test-Path $qgisInstaller) {
        Start-Process "msiexec.exe" -ArgumentList "/i `"$qgisInstaller`" /qn /norestart" -Wait
    }

    # Install Google Earth
    if (Test-Path $earthInstaller) {
        Start-Process $earthInstaller -ArgumentList "/S" -Wait
    }

    # Verify installations
    $qgisInstalled = Test-Path "C:\Program Files\QGIS*\bin\qgis-bin.exe"
    $earthInstalled = Test-Path "C:\Program Files\Google\Google Earth Pro\client\googleearth.exe"

    [PSCustomObject]@{
        Computer = $env:COMPUTERNAME
        QGIS = if($qgisInstalled){"Installed"}else{"Failed"}
        GoogleEarth = if($earthInstalled){"Installed"}else{"Failed"}
    }

} -ArgumentList $softwareLocation
