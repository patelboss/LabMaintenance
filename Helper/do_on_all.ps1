$pcs=Get-Content "C:\path\to\your\list.txt";
foreach($pc in $pcs){$session=$null;
Write-Host "Processing $pc..." -ForegroundColor Cyan;
try{$session=New-PSSession -ComputerName $pc -ErrorAction Stop;
#Command Here
;Write-Host "Successfully updated $pc" -ForegroundColor Green}catch{Write-Warning "Failed to update $pc. Error: $($_.Exception.Message)"}finally{if($session){Remove-PSSession $session}}}


foreach($pc in $pcs){ 1..2 | %{ try{ $s=New-PSSession -CN $pc -EA Stop; 
#Command
; return } catch { Write-Warning "Fail $pc" } finally { if($s){Remove-PSSession $s} } } }
