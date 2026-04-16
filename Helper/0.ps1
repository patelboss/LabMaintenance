That is a brilliant and highly logical way to reverse-engineer the problem 😉. By stripping away the "Master" configurations and enforcing the "Client" rules, we can essentially perform a targeted demotion of PC-27. 

In a Workgroup/Home Edition lab, the main difference between an Admin PC and a Client PC isn't the software—it’s who they trust, how they handle incoming traffic, and whether they hold onto saved credentials.

Here is your master checklist and the commands to convert any Admin PC into an obedient Client PC.

### 1. The "TrustedHosts" List (The Network Rolodex)
An **Admin PC** usually has `*` (trust everyone) or a massive list of IP addresses in this setting so it can send commands outward. A **Client PC** doesn't need to trust anyone to *receive* commands, or it should only trust the specific Admin PC.
* **Command to check:** ```powershell
    Get-Item WSMan:\localhost\Client\TrustedHosts
    ```
* **What it should be for a Client:** Empty (`""`) or exactly the Admin's name (`"PC-01"`). If you see a massive list or `*`, it still thinks it's a Master.
* **Command to fix (Wipe it clean):**
    ```powershell
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "" -Force
    ```

### 2. Saved Network Credentials (The Admin's Keys)
An **Admin PC** uses the Windows Credential Manager to store passwords for all the client PCs it connects to. A **Client PC** should not have saved passwords for other machines in the lab. If PC-27 has these, it is still acting like the boss.
* **Command to check:**
    ```powershell
    cmdkey /list
    ```
* **What it should be for a Client:** You should not see any entries starting with `Target: Domain:target=` followed by other PC names (like PC-02, PC-03, etc.).
* **Command to fix (Delete all saved lab credentials):**
    ```powershell
    # This deletes any saved network passwords
    cmdkey /list | Select-String "Target: " | ForEach-Object { cmdkey /delete:($_ -replace ".*Target: ","") }
    ```

### 3. Remote UAC / Token Filter (The Client Gateway)
An **Admin PC** doesn't strictly need this enabled just to *send* commands. However, a **Client PC** absolutely *must* have this enabled to accept administrative commands from the outside. 
* **Command to check:**
    ```powershell
    Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -ErrorAction SilentlyContinue
    ```
* **What it should be for a Client:** `1`
* **Command to fix:**
    ```powershell
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1 -PropertyType DWord -Force
    ```

### 4. ForceGuest Mode (The Home Edition Blocker)
Because you are using Home Edition, Windows defaults incoming network traffic to "Guest" level. An **Admin PC** doesn't care about this because it pushes traffic out. A **Client PC** will reject your remoting if this isn't turned off.
* **Command to check:**
    ```powershell
    Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "forceguest" -ErrorAction SilentlyContinue
    ```
* **What it should be for a Client:** `0` (or the property shouldn't exist at all). If it is `1`, it is blocking you.
* **Command to fix:**
    ```powershell
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "forceguest" -Value 0 -Type DWord -Force
    ```

### 5. WinRM Listeners (The "Ears")
An **Admin PC** sends commands, so it technically doesn't need to listen (though it usually does). A **Client PC** must have exactly one active HTTP listener on port 5985. If PC-27 used to be PC-01, it might have corrupted or duplicate listeners tied to the old name.
* **Command to check:**
    ```powershell
    winrm enumerate winrm/config/listener
    ```
* **What it should be for a Client:** You should see exactly one `Listener [Source="GPO"]` or `[Source="Compatibility"]` on `Port = 5985` with `Enabled = true`.
* **Command to fix (Wipe and rebuild the ears):**
    ```powershell
    winrm invoke restore winrm/config
    winrm quickconfig -force
    ```

### 6. The Execution Policy
An **Admin PC** often needs an `Unrestricted` or `Bypass` policy to run massive deployment scripts. A **Client PC** usually operates on `RemoteSigned`. 
* **Command to check:**
    ```powershell
    Get-ExecutionPolicy
    ```
* **What it should be for a Client:** `RemoteSigned`
* **Command to fix:**
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Force
    ```
