#Requires -RunAsAdministrator
# FTP-Hardening-Verify.ps1
# Verifies common CCDC hardening items (services/registry/firewall/audit/ports).
# Outputs PASS/FAIL per check + a summary exit code (0=all pass, 1=some fail)

$ErrorActionPreference = "SilentlyContinue"

# --- EDIT ME (must match your hardening values) ---
$ExpectedDisabledServices = @(
  "Spooler",
  "RemoteRegistry",
  "Fax",
  "BluetoothSupportService",
  "CscService",   # Offline Files
  "WerSvc"        # Windows Error Reporting (if you disabled it)
)

$ExpectWinRMDisabled = $true

$FtpControlPort   = 21
$PassivePortRange = "50000-50100"   # must match your firewall rule
$ExpectSMBv1Off    = $true
$ExpectLLMNROff    = $true

# Firewall rule display names you used in hardening
$FwRuleFtpControl = "CCDC-FTP-Control"
$FwRuleFtpPassive = "CCDC-FTP-Passive"

# Optional: RDP restricted rule prefix (if you used it)
$FwRuleRdpPrefix  = "CCDC-RDP-Admin-"
# -----------------------------------------------

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

Write-Host "=== FTP Hardening Verification ==="

# 1) Services disabled
foreach ($svc in $ExpectedDisabledServices) {
  $r = Service-IsDisabledStopped $svc
  Add-Result "Service disabled: $svc" $r.ok $r.details
}

if ($ExpectWinRMDisabled) {
  $r = Service-IsDisabledStopped "WinRM"
  Add-Result "Service disabled: WinRM" $r.ok $r.details
}

# 2) SMBv1 disabled
if ($ExpectSMBv1Off) {
  $feat = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
  $ok = ($feat.State -eq "Disabled")
  Add-Result "SMBv1 disabled (SMB1Protocol feature)" $ok "State=$($feat.State)"
}

# 3) LLMNR disabled
if ($ExpectLLMNROff) {
  $v = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name EnableMulticast -ErrorAction SilentlyContinue).EnableMulticast
  $ok = ($v -eq 0)
  Add-Result "LLMNR disabled (EnableMulticast=0)" $ok "EnableMulticast=$v"
}

# 4) PowerShell logging enabled
$sb = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -ErrorAction SilentlyContinue).EnableScriptBlockLogging
$ml = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name EnableModuleLogging -ErrorAction SilentlyContinue).EnableModuleLogging
Add-Result "PowerShell ScriptBlockLogging enabled" ($sb -eq 1) "EnableScriptBlockLogging=$sb"
Add-Result "PowerShell ModuleLogging enabled" ($ml -eq 1) "EnableModuleLogging=$ml"

# 5) Firewall enabled + inbound blocked policy
$profiles = Get-NetFirewallProfile
$fwOn = ($profiles | Where-Object { $_.Enabled -ne $true }).Count -eq 0
Add-Result "Windows Firewall enabled (all profiles)" $fwOn ("Profiles: " + (($profiles | ForEach-Object { "$($_.Name)=$($_.Enabled)" }) -join ", "))

$inboundPolicyOk = ($profiles | Where-Object { $_.DefaultInboundAction -ne "Block" }).Count -eq 0
Add-Result "Firewall default inbound policy = Block" $inboundPolicyOk ("Inbound: " + (($profiles | ForEach-Object { "$($_.Name)=$($_.DefaultInboundAction)" }) -join ", "))

# 6) Firewall rules exist for FTP control/passive + correct ports
$ruleC = Get-NetFirewallRule -DisplayName $FwRuleFtpControl
if ($ruleC) {
  $pf = $ruleC | Get-NetFirewallPortFilter
  $ok = ($pf.Protocol -eq "TCP") -and ($pf.LocalPort -contains "$FtpControlPort")
  Add-Result "Firewall rule exists: $FwRuleFtpControl" $ok ("Protocol=$($pf.Protocol) LocalPort=$($pf.LocalPort -join ',')")
} else {
  Add-Result "Firewall rule exists: $FwRuleFtpControl" $false "Not found"
}

$ruleP = Get-NetFirewallRule -DisplayName $FwRuleFtpPassive
if ($ruleP) {
  $pf = $ruleP | Get-NetFirewallPortFilter
  $ok = ($pf.Protocol -eq "TCP") -and ($pf.LocalPort -contains $PassivePortRange)
  Add-Result "Firewall rule exists: $FwRuleFtpPassive" $ok ("Protocol=$($pf.Protocol) LocalPort=$($pf.LocalPort -join ',')")
} else {
  Add-Result "Firewall rule exists: $FwRuleFtpPassive" $false "Not found"
}

# 7) Listening ports sanity (FTP port should be listening if service is running)
$listening = Get-NetTCPConnection -State Listen | Select-Object -Expand LocalPort
$ftpListenOk = ($listening -contains $FtpControlPort)
Add-Result "FTP control port listening (expected if FTP running)" $ftpListenOk "ListeningPortsContains=$FtpControlPort"

# 8) Audit policy (quick spot check)
# These commands return text; we just check for "Success and Failure" where expected.
$a1 = (auditpol /get /category:"Logon/Logoff") -join "`n"
$a2 = (auditpol /get /category:"Account Logon") -join "`n"
Add-Result "Audit policy set: Logon/Logoff enabled" ($a1 -match "Success\s+and\s+Failure") "auditpol(Logon/Logoff) parsed"
Add-Result "Audit policy set: Account Logon enabled" ($a2 -match "Success\s+and\s+Failure") "auditpol(Account Logon) parsed"

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
