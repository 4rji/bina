#Requires -RunAsAdministrator
# AD-DNS-Hardening-Verify.ps1
# PASS/FAIL verification for the AD-DNS hardening script.
# Exit code: 0 = all pass, 1 = failures

$ErrorActionPreference = "SilentlyContinue"

# ---- EDIT TO MATCH YOUR HARDENING ----
$ExpectedDisabledServices = @(
  "Spooler",
  "RemoteRegistry",
  "Fax",
  "BluetoothSupportService",
  "WerSvc",
  "WinRM"     # remove if you kept WinRM
  # "DFSR"    # include if you disabled DFSR
)

$ExpectSMBv1Off     = $true
$ExpectLLMNROff     = $true
$ExpectNetBIOSOff   = $true
$ExpectNTLMv2       = $true
$ExpectWDigestOff   = $true

$ExpectedNtpPeer    = "time.windows.com"

# Firewall rules created by the hardening script
$FwRulePrefix       = "CCDC-DC-Allow-"
$CorePorts          = @(53,88,135,389,445,464,636,3268,3269)

# DNS expectations
$ExpectDnsRecursionDisabled = $true  # set $false if your DNS must recurse
$ExpectSecureDynamicUpdates = $true
# --------------------------------------

$results = New-Object System.Collections.Generic.List[object]

function Add-Result($name, $ok, $details) {
  $results.Add([pscustomobject]@{
    Check   = $name
    Status  = if ($ok) { "PASS" } else { "FAIL" }
    Details = $details
  }) | Out-Null
}

function Service-IsDisabledStopped($svcName) {
  $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
  if (-not $s) { return @{ ok = $true; details = "Service not present" } }
  $startType = (Get-CimInstance Win32_Service -Filter "Name='$svcName'" | Select-Object -Expand StartMode)
  $ok = ($s.Status -eq "Stopped") -and ($startType -eq "Disabled")
  return @{ ok = $ok; details = "Status=$($s.Status) StartMode=$startType" }
}

Write-Host "=== AD + DNS Hardening Verification ==="

# 1) Services
foreach ($svc in $ExpectedDisabledServices) {
  $r = Service-IsDisabledStopped $svc
  Add-Result "Service disabled: $svc" $r.ok $r.details
}

# 2) SMBv1
if ($ExpectSMBv1Off) {
  $feat = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
  Add-Result "SMBv1 disabled" ($feat.State -eq "Disabled") "State=$($feat.State)"
}

# 3) LLMNR
if ($ExpectLLMNROff) {
  $v = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name EnableMulticast -ErrorAction SilentlyContinue).EnableMulticast
  Add-Result "LLMNR disabled (EnableMulticast=0)" ($v -eq 0) "EnableMulticast=$v"
}

# 4) NetBIOS
if ($ExpectNetBIOSOff) {
  $bad = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" |
    Where-Object { $_.TcpipNetbiosOptions -ne 2 }
  Add-Result "NetBIOS disabled on all NICs" ($bad.Count -eq 0) "NonCompliantNICs=$($bad.Count)"
}

# 5) NTLMv2 enforced
if ($ExpectNTLMv2) {
  $lm = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name LmCompatibilityLevel -ErrorAction SilentlyContinue).LmCompatibilityLevel
  Add-Result "NTLMv2 enforced (LmCompatibilityLevel=5)" ($lm -eq 5) "LmCompatibilityLevel=$lm"
}

# 6) WDigest off
if ($ExpectWDigestOff) {
  $wd = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name UseLogonCredential -ErrorAction SilentlyContinue).UseLogonCredential
  Add-Result "WDigest disabled (UseLogonCredential=0)" ($wd -eq 0) "UseLogonCredential=$wd"
}

# 7) PowerShell logging
$sb = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -ErrorAction SilentlyContinue).EnableScriptBlockLogging
$ml = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name EnableModuleLogging -ErrorAction SilentlyContinue).EnableModuleLogging
Add-Result "PowerShell ScriptBlockLogging enabled" ($sb -eq 1) "EnableScriptBlockLogging=$sb"
Add-Result "PowerShell ModuleLogging enabled" ($ml -eq 1) "EnableModuleLogging=$ml"

# 8) Audit policy (quick parse)
$a1 = (auditpol /get /category:"Logon/Logoff") -join "`n"
$a2 = (auditpol /get /category:"Account Logon") -join "`n"
Add-Result "Audit: Logon/Logoff enabled" ($a1 -match "Success\s+and\s+Failure") "auditpol parsed"
Add-Result "Audit: Account Logon enabled" ($a2 -match "Success\s+and\s+Failure") "auditpol parsed"

# 9) NTP peer
$ntp = (w32tm /query /configuration) -join "`n"
Add-Result "Time source contains expected peer" ($ntp -match [regex]::Escape($ExpectedNtpPeer)) "Expected=$ExpectedNtpPeer"

# 10) Firewall enabled + default inbound block
$profiles = Get-NetFirewallProfile
Add-Result "Firewall enabled (all profiles)" (($profiles | Where-Object { $_.Enabled -ne $true }).Count -eq 0) `
  ("Profiles: " + (($profiles | ForEach-Object { "$($_.Name)=$($_.Enabled)" }) -join ", "))
Add-Result "Firewall inbound default = Block" (($profiles | Where-Object { $_.DefaultInboundAction -ne "Block" }).Count -eq 0) `
  ("Inbound: " + (($profiles | ForEach-Object { "$($_.Name)=$($_.DefaultInboundAction)" }) -join ", "))

# 11) Firewall rules exist for core ports (TCP+UDP)
foreach ($p in $CorePorts) {
  $tcpRule = Get-NetFirewallRule -DisplayName "$FwRulePrefix$p" -ErrorAction SilentlyContinue
  $udpRule = Get-NetFirewallRule -DisplayName "$FwRulePrefix$p-UDP" -ErrorAction SilentlyContinue
  Add-Result "FW rule exists TCP $p" ([bool]$tcpRule) (if ($tcpRule) { "OK" } else { "Missing" })
  Add-Result "FW rule exists UDP $p" ([bool]$udpRule) (if ($udpRule) { "OK" } else { "Missing" })
}

# 12) DNS checks
try {
  Import-Module DNSServer -ErrorAction Stop

  if ($ExpectDnsRecursionDisabled) {
    $rec = Get-DnsServerRecursion
    Add-Result "DNS recursion disabled" ($rec.Enable -eq $false) "Enable=$($rec.Enable)"
  }

  if ($ExpectSecureDynamicUpdates) {
    $zones = Get-DnsServerZone | Where-Object { $_.IsDsIntegrated }
    $badZones = @()
    foreach ($z in $zones) {
      # Secure = "Secure" / "Secure" enum depending on version
      if ($z.DynamicUpdate -notmatch "Secure") { $badZones += $z.ZoneName }
    }
    Add-Result "DNS zones use Secure dynamic updates" ($badZones.Count -eq 0) ("NonSecureZones=" + ($badZones -join ", "))
  }
} catch {
  Add-Result "DNS module checks" $false "DNSServer module unavailable"
}

# --- Output ---
$results | Format-Table -AutoSize

$fails = $results | Where-Object { $_.Status -eq "FAIL" }
if ($fails.Count -gt 0) {
  Write-Host "`n=== SUMMARY: FAIL ($($fails.Count) checks) ==="
  $fails | Format-Table -AutoSize
  exit 1
} else {
  Write-Host "`n=== SUMMARY: PASS (all checks) ==="
  exit 0
}
