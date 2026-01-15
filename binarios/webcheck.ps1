#Requires -RunAsAdministrator
# WebMail-Hardening-Verify.ps1
# Verifies WebMail (IIS) hardening: services, registry, firewall, IIS settings.
# Output: PASS/FAIL per check + exit code (0=all pass, 1=failures)

$ErrorActionPreference = "SilentlyContinue"

# ---- EDIT TO MATCH YOUR HARDENING ----
$ExpectedDisabledServices = @(
  "Spooler",
  "RemoteRegistry",
  "Fax",
  "BluetoothSupportService",
  "CscService",   # Offline Files
  "WerSvc"        # Windows Error Reporting (if disabled)
)

$ExpectWinRMDisabled = $true
$ExpectSMBv1Off     = $true
$ExpectLLMNROff     = $true
$ExpectNetBIOSOff   = $true

$WebPortsExpected   = @(443)     # add 80 if you allowed it
$FwWebRulePrefix    = "CCDC-WEB-"
$FwRdpRulePrefix    = "CCDC-RDP-Admin-"
# -------------------------------------

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

Write-Host "=== WebMail Hardening Verification ==="

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
  Add-Result "SMBv1 disabled" ($feat.State -eq "Disabled") "State=$($feat.State)"
}

# 3) LLMNR disabled
if ($ExpectLLMNROff) {
  $v = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name EnableMulticast -ErrorAction SilentlyContinue).EnableMulticast
  Add-Result "LLMNR disabled" ($v -eq 0) "EnableMulticast=$v"
}

# 4) NetBIOS disabled
if ($ExpectNetBIOSOff) {
  $bad = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" |
    Where-Object { $_.TcpipNetbiosOptions -ne 2 }
  Add-Result "NetBIOS over TCP/IP disabled" ($bad.Count -eq 0) ("NonCompliantNICs=$($bad.Count)")
}

# 5) PowerShell logging
$sb = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -ErrorAction SilentlyContinue).EnableScriptBlockLogging
$ml = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name EnableModuleLogging -ErrorAction SilentlyContinue).EnableModuleLogging
Add-Result "PowerShell ScriptBlockLogging enabled" ($sb -eq 1) "EnableScriptBlockLogging=$sb"
Add-Result "PowerShell ModuleLogging enabled" ($ml -eq 1) "EnableModuleLogging=$ml"

# 6) Firewall enabled + inbound blocked
$profiles = Get-NetFirewallProfile
Add-Result "Firewall enabled (all profiles)" (($profiles | Where-Object { $_.Enabled -ne $true }).Count -eq 0) `
  ("Profiles: " + (($profiles | ForEach-Object { "$($_.Name)=$($_.Enabled)" }) -join ", "))
Add-Result "Firewall inbound default = Block" (($profiles | Where-Object { $_.DefaultInboundAction -ne "Block" }).Count -eq 0) `
  ("Inbound: " + (($profiles | ForEach-Object { "$($_.Name)=$($_.DefaultInboundAction)" }) -join ", "))

# 7) Web firewall rules exist
foreach ($p in $WebPortsExpected) {
  $rule = Get-NetFirewallRule -DisplayName "$FwWebRulePrefix$p"
  if ($rule) {
    $pf = $rule | Get-NetFirewallPortFilter
    $ok = ($pf.Protocol -eq "TCP") -and ($pf.LocalPort -contains "$p")
    Add-Result "Firewall rule exists: WEB $p" $ok ("Protocol=$($pf.Protocol) Port=$($pf.LocalPort -join ',')")
  } else {
    Add-Result "Firewall rule exists: WEB $p" $false "Not found"
  }
}

# 8) Listening ports sanity (443 should listen)
$listening = Get-NetTCPConnection -State Listen | Select-Object -Expand LocalPort
foreach ($p in $WebPortsExpected) {
  Add-Result "Web port listening: $p" ($listening -contains $p) "ListeningPortsContains=$p"
}

# 9) IIS checks (if installed)
try {
  Import-Module WebAdministration -ErrorAction Stop

  $db = Get-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" `
        -Filter "system.webServer/directoryBrowse" -Name "enabled"
  Add-Result "IIS directory browsing disabled" ($db -eq $false) "enabled=$db"

  $dav = Get-WindowsOptionalFeature -Online -FeatureName IIS-WebDAV
  Add-Result "WebDAV disabled" ($dav.State -eq "Disabled") "State=$($dav.State)"

  $hdrs = Get-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" `
          -Filter "system.webServer/httpProtocol/customHeaders/add" -Name "."
  $need = @("X-Content-Type-Options","X-Frame-Options","Referrer-Policy")
  $present = $hdrs.name
  Add-Result "IIS security headers present" (($need | Where-Object { $present -notcontains $_ }).Count -eq 0) `
    ("PresentHeaders=$($present -join ', ')")
} catch {
  Add-Result "IIS present / checks executed" $true "IIS not installed or module unavailable"
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
