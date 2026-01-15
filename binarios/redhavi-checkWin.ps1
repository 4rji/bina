#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

############################################
# CLEANUP VERIFIER (Windows) - COMPLETE v2
############################################

$script:TOTAL_CHECKS  = 0
$script:PASSED_CHECKS = 0

function Ok($msg){ Write-Host "[OK] $msg" -ForegroundColor Green; $script:PASSED_CHECKS++ }
function X ($msg){ Write-Host "[X]  $msg" -ForegroundColor Red }
function Check($name, [scriptblock]$sb){
  $script:TOTAL_CHECKS++
  try { & $sb; Ok $name }
  catch { X "$name -> $($_.Exception.Message)" }
}

function Test-Command($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# --- CONFIG ---
$AllowedLocalUsers = @("Administrator","DefaultAccount","Guest","WDAGUtilityAccount")
$EnforceAllowlistUsers = $false

$MustNotExistUsers = @("backup","admin2","test","support","ssh","svc","temp")

# Ports that are “actually suspicious” for a lab endpoint baseline
$RiskyListeningPorts = @(22,23,4444,31337,1337,6666,7777,8080,9001,9002,9999)

# Paths that are usually OK for legit binaries
$AllowedBinaryRoots = @(
  "C:\Windows\",
  "C:\Program Files\",
  "C:\Program Files (x86)\",
  "C:\ProgramData\Microsoft\"
)

# Allow common Run entries (add more if you want)
$AllowedRunNames = @(
  "SecurityHealth",
  "SecurityHealthSystray",
  "OneDrive",
  "WindowsDefender",
  "RtkAudUService",
  "IgfxTray","HotKeysCmds","Persistence"
)

# Allow tasks under these roots (Windows built-ins)
$AllowedTaskPathPrefixes = @(
  "\Microsoft\Windows\",
  "\MicrosoftEdgeUpdateTask"
)

# --- HELPERS ---
function Get-LocalUsersSafe {
  try { Get-LocalUser | Select-Object -ExpandProperty Name }
  catch {
    (net user) | ForEach-Object { $_.Trim() } |
      Where-Object { $_ -and $_ -notmatch '^(User accounts for|---|The command completed)' } |
      ForEach-Object { $_ -split '\s+' } | ForEach-Object { $_ } |
      Where-Object { $_ }
  }
}

function Find-AuthorizedKeys {
  $hits = @()
  if (Test-Path "C:\Users") {
    Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $p = Join-Path $_.FullName ".ssh\authorized_keys"
      if (Test-Path $p) { $hits += $p }
    }
  }
  $sys = "C:\ProgramData\ssh\administrators_authorized_keys"
  if (Test-Path $sys) { $hits += $sys }
  return $hits
}

function Get-RunPersistence {
  $paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
  )
  $items = @()
  foreach ($p in $paths) {
    if (Test-Path $p) {
      $props = Get-ItemProperty $p
      $props.PSObject.Properties |
        Where-Object { $_.Name -notmatch '^PS' -and $_.Value } |
        ForEach-Object {
          $items += [pscustomobject]@{ Path=$p; Name=$_.Name; Value=[string]$_.Value }
        }
    }
  }
  return $items
}

function Get-StartupFolderItems {
  $folders = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup"
  )
  $items = @()
  foreach ($f in $folders) {
    if (Test-Path $f) {
      $items += Get-ChildItem $f -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }
  }
  return $items
}

function Get-ListeningPorts {
  try {
    Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort -Unique | Sort-Object
  } catch {
    (netstat -ano -p tcp | Select-String "LISTENING" | ForEach-Object {
      ($_.ToString() -split '\s+')[2].Split(':')[-1] -as [int]
    } | Sort-Object -Unique)
  }
}

function Is-AllowedBinaryPath([string]$cmdline) {
  if (-not $cmdline) { return $true }
  $c = $cmdline.Trim()

  # try to extract exe path (quoted or first token)
  $exe = $null
  if ($c.StartsWith('"')) {
    $exe = ($c -split '"')[1]
  } else {
    $exe = ($c -split '\s+')[0]
  }
  if (-not $exe) { return $true }

  # environment vars expansion
  $exe = [Environment]::ExpandEnvironmentVariables($exe)

  foreach ($root in $AllowedBinaryRoots) {
    if ($exe.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}

function Is-MicrosoftService([string]$svcName) {
  try {
    $p = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
    $img = (Get-ItemProperty $p -ErrorAction Stop).ImagePath
    if ($img) {
      $img = [Environment]::ExpandEnvironmentVariables([string]$img)
      return (Is-AllowedBinaryPath $img)
    }
  } catch {}
  # if unknown, don't auto-bless
  return $false
}

############################################
# CHECKS
############################################

Check "No denylisted local users exist" {
  $users = Get-LocalUsersSafe
  $found = $MustNotExistUsers | Where-Object { $users -contains $_ }
  if ($found) { throw ("Found forbidden users: " + ($found -join ", ")) }
}

Check "No unexpected local users (allowlist baseline) [optional]" {
  if (-not $EnforceAllowlistUsers) { return }
  $users = Get-LocalUsersSafe
  $unexpected = $users | Where-Object { $AllowedLocalUsers -notcontains $_ }
  if ($unexpected) { throw ("Unexpected local users: " + ($unexpected -join ", ")) }
}

Check "No authorized_keys present (user/system)" {
  $keys = Find-AuthorizedKeys
  if ($keys.Count -gt 0) { throw ("authorized_keys found: " + ($keys -join " | ")) }
}

Check "Scheduled tasks: only flag non-Windows/root-odd tasks" {
  $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
  $bad = New-Object System.Collections.Generic.List[string]

  foreach ($t in $tasks) {
    $full = "$($t.TaskPath)$($t.TaskName)"

    $isAllowedPath = $false
    foreach ($pref in $AllowedTaskPathPrefixes) {
      if ($full.StartsWith($pref, [System.StringComparison]::OrdinalIgnoreCase)) { $isAllowedPath = $true; break }
    }

    # If it's a Windows/Microsoft task path prefix, ignore
    if ($isAllowedPath) { continue }

    # Otherwise inspect actions for weird binary paths
    $info = Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
    $cmds = @()
    try {
      $cmds = $t.Actions | ForEach-Object {
        if ($_.Execute) { "$($_.Execute) $($_.Arguments)" } else { "" }
      }
    } catch {}

    $weird = $false
    foreach ($c in $cmds) {
      if (-not (Is-AllowedBinaryPath $c)) { $weird = $true; break }
    }

    if ($weird -or -not $isAllowedPath) {
      $bad.Add($full)
    }
  }

  if ($bad.Count -gt 0) { throw ("Suspicious tasks: " + (($bad | Select-Object -First 25 -Unique) -join ", ")) }
}

Check "Services: only flag services with binary outside allowed roots" {
  $svcs = Get-Service | Select-Object -ExpandProperty Name
  $bad = New-Object System.Collections.Generic.List[string]

  foreach ($s in $svcs) {
    # bless services whose ImagePath resolves inside allowed roots
    if (Is-MicrosoftService $s) { continue }

    # if not blessed, check if it even has an ImagePath (some are virtual)
    $img = $null
    try {
      $p = "HKLM:\SYSTEM\CurrentControlSet\Services\$s"
      $img = (Get-ItemProperty $p -ErrorAction Stop).ImagePath
    } catch {}

    if (-not $img) { continue } # virtual/driver without ImagePath string: ignore

    $img = [Environment]::ExpandEnvironmentVariables([string]$img)
    if (-not (Is-AllowedBinaryPath $img)) {
      $bad.Add("$s -> $img")
    }
  }

  if ($bad.Count -gt 0) { throw ("Suspicious services: " + (($bad | Select-Object -First 25 -Unique) -join " | ")) }
}

Check "Run/RunOnce: only flag entries not in allowlist and pointing outside allowed roots" {
  $runs = Get-RunPersistence
  $bad = New-Object System.Collections.Generic.List[string]

  foreach ($r in $runs) {
    if ($AllowedRunNames -contains $r.Name) { continue }

    # allow SecurityHealth* variants
    if ($r.Name -like "SecurityHealth*") { continue }

    if (-not (Is-AllowedBinaryPath $r.Value)) {
      $bad.Add("$($r.Path)\$($r.Name)=$($r.Value)")
    }
  }

  if ($bad.Count -gt 0) { throw ("Suspicious Run entries: " + (($bad | Select-Object -First 25 -Unique) -join " | ")) }
}

Check "Startup folders clean (no files)" {
  $items = Get-StartupFolderItems
  if ($items.Count -gt 0) { throw ("Startup items: " + ($items -join " | ")) }
}

Check "No risky ports are listening" {
  $ports = Get-ListeningPorts
  $hit = $ports | Where-Object { $RiskyListeningPorts -contains $_ }
  if ($hit) { throw ("Risky listening ports: " + ($hit -join ", ")) }
}

Check "No leftover packages installed (winget/choco) matching deny terms" {
  # This is optional/weak. Leave it as pass unless exact denylist is provided.
  $deny = @("xray","frp","ngrok","tailscale","anydesk","teamviewer","openssh","putty")
  $bad = New-Object System.Collections.Generic.List[string]

  if (Test-Command winget) {
    $w = (winget list 2>$null) -join "`n"
    foreach ($d in $deny) { if ($w -match $d) { $bad.Add("winget: $d") } }
  }

  if (Test-Command choco) {
    $c = (choco list --local-only 2>$null) -join "`n"
    foreach ($d in $deny) { if ($c -match $d) { $bad.Add("choco: $d") } }
  }

  if ($bad.Count -gt 0) { throw ($bad -join " | ") }
}

############################################
# FINAL SCORE SUMMARY
############################################
Write-Host ""
Write-Host "=== FINAL CLEANUP SCORE ==="
Write-Host ""

$FAILED  = $TOTAL_CHECKS - $PASSED_CHECKS
$PERCENT = if ($TOTAL_CHECKS -gt 0) { [int](100 * $PASSED_CHECKS / $TOTAL_CHECKS) } else { 0 }

Write-Host "Total Checks:      $TOTAL_CHECKS"
Write-Host "Passed (OK):       $PASSED_CHECKS"
Write-Host "Failed (X):        $FAILED"
Write-Host "Score Percentage:  $PERCENT%"

Write-Host ""
Write-Host "============================="

if ($PERCENT -eq 100) {
  Write-Host "System fully cleaned. Excellent work!"
} elseif ($PERCENT -ge 80) {
  Write-Host "Good cleanup. A few items remain."
} elseif ($PERCENT -ge 50) {
  Write-Host "Partial cleanup. Several issues still present."
} else {
  Write-Host "System still compromised. Needs major cleanup."
}

Write-Host "============================="
Write-Host ""
