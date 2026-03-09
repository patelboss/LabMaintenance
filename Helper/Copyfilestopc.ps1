# =================================
# CONFIG
# =================================
$pcs  = @("PC-02","PC-03","PC-04")   # client PCs
$From = "C:\Setup_Source"
$Dest = "C:\Program Files\Lab_Data"

# =================================
# DEPLOY TO CLIENTS
# =================================
foreach ($pc in $pcs) {

Invoke-Command -ComputerName $pc -ScriptBlock {

param($From,$Dest)

# Create destination
if (!(Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}

# Copy files
Copy-Item "$From\*" $Dest -Recurse -Force

# Hide folder
attrib +h +s $Dest

# Set permissions
$acl = Get-Acl $Dest
$acl.SetAccessRuleProtection($true,$false)

$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule(
"Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow")

$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule(
"SYSTEM","FullControl","ContainerInherit,ObjectInherit","None","Allow")

$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule(
"Users","ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow")

$acl.SetAccessRule($rule1)
$acl.AddAccessRule($rule2)
$acl.AddAccessRule($rule3)

Set-Acl $Dest $acl

} -ArgumentList $From,$Dest

Write-Host "$pc deployment complete"

}
