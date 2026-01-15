#Requires -RunAsAdministrator
# AD-DNS-Hardening.ps1 (fixed)
# CCDC hardening for DC + DNS, non-destructive defaults, best-effort removals.

$ErrorActionPreference = "Stop"

# ---- EDIT ME ----
$TrustedNtpServer = "time.windows.com"
$DisableDFS       = $true          # set $false if DFS is required
$DisableADLDS     = $true          # best-effort remove if installed
$DisableSpooler   = $true
$DisableWinRM     = $true
$DisableSMBv1     = $true
$DisableLLMNR     = $true
$DisableNetBIOS   = $true

# DNS recursion: only disable if you are sure DC should NOT be a recursive resolver for clients
$DisableDnsRecursion = $false
# -----------------

function Disable-ServiceSafe($name) {
  $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
  if ($svc) {
    if ($svc.Status -ne "Stopped") { Stop-Service -Name $name -Force -ErrorAction SilentlyContinue }
    Set-Service -Name $name -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "[OK] Disabled service: $name"
  } else {
    Write-Host "[..] Service not present: $name"
  }
}
function Set-RegDword($path, $name, $value) {
  # Do NOT New-Item on protected keys; assume key exists and just set/create the value.
  try {
    Set-ItemProperty -Path $path -Name $name -Value $value -Type DWord -ErrorAction Stop | Out-Null
  } catch {
    try {
      New-ItemProperty -Path $path -Name $name -PropertyType DWord -Value $value -Force -ErrorAction Stop | Out-Null
    } catch {
      Write-Host "[!!] Registry set failed: $path\$name -> $($_.Exception.Message)"
    }
  }
}


function Try-DisableFeature($name) {
  $f = Get-WindowsFeature -Name $name -ErrorAction SilentlyContinue
  if ($f -and $f.Installed) {
    Remove-WindowsFeature -Name $name -IncludeManagementTools -Restart:$false | Out-Null
    Write-Host "[OK] Removed WindowsFeature: $name"
  } elseif ($f) {
    Write-Host "[..] Feature not installed: $name"
  } else {
    Write-Host "[..] Feature unknown on this host: $name"
  }
}

Write-Host "=== AD + DNS Hardening (CCDC) ==="

# --- Kill obvious lateral-move services ---
if ($DisableSpooler) { Disable-ServiceSafe "Spooler" }
Disable-ServiceSafe "RemoteRegistry"
Disable-ServiceSafe "Fax"
Disable-ServiceSafe "BluetoothSupportService"
Disable-ServiceSafe "WerSvc"

if ($DisableWinRM) { Disable-ServiceSafe "WinRM" }

# --- Optional role cleanup (best-effort) ---
if ($DisableADLDS) {
  # AD LDS role on Server is "ADLDS"
  Try-DisableFeature "ADLDS"
  # Also remove RSAT AD LDS tools if present
  Try-DisableFeature "RSAT-ADLDS"
}

if ($DisableDFS) {
  Disable-ServiceSafe "DFSR"
  # If DFS Namespaces/Replication roles were installed, remove them best-effort:
  Try-DisableFeature "FS-DFS-Namespace"
  Try-DisableFeature "FS-DFS-Replication"
}

# --- SMBv1 OFF ---
if ($DisableSMBv1) {
  Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
  Write-Host "[OK] SMBv1 disabled."
}

# --- LLMNR OFF ---
if ($DisableLLMNR) {
  Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
  Write-Host "[OK] LLMNR disabled."
}

# --- NetBIOS OFF (CIM, no WMI) ---
try {
  $nics = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE"
  foreach ($nic in $nics) {
    try {
      Invoke-CimMethod -InputObject $nic -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = 2 } | Out-Null
      Write-Host "[OK] NetBIOS disabled on: $($nic.Description)"
    } catch {
      Write-Host "[!!] NetBIOS disable failed on: $($nic.Description) -> $($_.Exception.Message)"
    }
  }
} catch {
  Write-Host "[!!] CIM query failed for NICs (skipping NetBIOS step): $($_.Exception.Message)"
}



# --- NTLM hardening ---
Set-RegDword "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LmCompatibilityLevel" 5
Set-RegDword "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" "UseLogonCredential" 0
Write-Host "[OK] NTLMv2 enforced, WDigest disabled."

# --- PowerShell logging ---
Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" "EnableScriptBlockLogging" 1
Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" "EnableModuleLogging" 1
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Name "*" -PropertyType String -Value "*" -Force | Out-Null
Write-Host "[OK] PowerShell logging enabled."

# --- Advanced auditing ---
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable | Out-Null
auditpol /set /category:"Account Logon" /success:enable /failure:enable | Out-Null
auditpol /set /category:"Account Management" /success:enable /failure:enable | Out-Null
auditpol /set /category:"Policy Change" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Process Creation" /success:enable /failure:disable | Out-Null
Write-Host "[OK] Advanced audit policy enabled."

# --- DNS hardening ---
try {
  Import-Module DNSServer -ErrorAction Stop

  # Zone transfers OFF (best-effort per zone)
  Get-DnsServerZone | Where-Object { $_.ZoneType -eq "Primary" } | ForEach-Object {
    try {
      Set-DnsServerPrimaryZone -Name $_.ZoneName -SecureSecondaries NoTransfer -ErrorAction Stop
    } catch {}
  }

  # Secure dynamic updates for AD-integrated zones
  Get-DnsServerZone | Where-Object { $_.IsDsIntegrated } | ForEach-Object {
    Set-DnsServerPrimaryZone -Name $_.ZoneName -DynamicUpdate Secure -ErrorAction SilentlyContinue
  }

  if ($DisableDnsRecursion) {
    Set-DnsServerRecursion -Enable $false -ErrorAction SilentlyContinue
    Write-Host "[OK] DNS recursion disabled."
  } else {
    Write-Host "[..] DNS recursion unchanged."
  }

  Write-Host "[OK] DNS: zone transfers off + secure dynamic updates (AD zones)."
} catch {
  Write-Host "[..] DNS module not available or partial DNS hardening skipped."
}

# --- Time source hardening ---
w32tm /config /manualpeerlist:$TrustedNtpServer /syncfromflags:manual /reliable:yes /update | Out-Null
Restart-Service w32time
Write-Host "[OK] Time source set to trusted NTP."

# --- Firewall baseline ---
netsh advfirewall set allprofiles state on | Out-Null
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound | Out-Null

# Core DC ports (TCP/UDP where appropriate)
$TcpPorts = @(53,88,135,389,445,464,636,3268,3269)
$UdpPorts = @(53,88,123,389,464)  # include NTP 123/UDP
foreach ($p in $TcpPorts) {
  New-NetFirewallRule -DisplayName "CCDC-DC-Allow-TCP-$p" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p -Profile Any | Out-Null
}
foreach ($p in $UdpPorts) {
  New-NetFirewallRule -DisplayName "CCDC-DC-Allow-UDP-$p" -Direction Inbound -Action Allow -Protocol UDP -LocalPort $p -Profile Any | Out-Null
}
Write-Host "[OK] Firewall locked to core AD/DNS ports (plus NTP UDP/123)."

Write-Host "=== Done. Reboot recommended if features changed. ==="
