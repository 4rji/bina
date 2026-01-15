#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# --- CONFIG ---
$RepoUrl   = "https://github.com/banago/simple-php-website.git"
$WebRoot   = "C:\www\simple-php-website"
$IndexUrl  = "https://raw.githubusercontent.com/4rji/ccdc/main/index.php"
$IndexPath = Join-Path $WebRoot "index.php"

# XAMPP path (choco)
$XamppDir  = "C:\tools\xampp"
$ApacheExe = Join-Path $XamppDir "apache_start.bat"

# Optional “cron” equivalent
$RefreshUrl = "http://10.5.8.11/index.php"
$EnableRefreshTask = $false

function Test-Command($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Ensure-Choco {
  if (Test-Command choco) { return }
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  iex ((New-Object Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1"))
}

function Choco-Install {
  param([string[]]$Pkgs)
  Ensure-Choco
  foreach ($p in $Pkgs) {
    choco install -y $p --no-progress
  }
}

function Resolve-GitExe {
  $cmd = Get-Command git -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $candidates = @(
    "$env:ProgramFiles\Git\cmd\git.exe",
    "$env:ProgramFiles\Git\bin\git.exe",
    "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
    "${env:ProgramFiles(x86)}\Git\bin\git.exe",
    "$env:LocalAppData\Programs\Git\cmd\git.exe",
    "$env:LocalAppData\Programs\Git\bin\git.exe"
  )
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  throw "git.exe no encontrado (reabre PowerShell si se acaba de instalar Git)."
}

function Invoke-Native {
  param([Parameter(Mandatory)][string]$FilePath, [Parameter(Mandatory)][string[]]$Args)
  & $FilePath @Args
  if ($LASTEXITCODE -ne 0) { throw "Falló ($LASTEXITCODE): $FilePath $($Args -join ' ')" }
}

function Lock-FileAclReadOnly {
  param([Parameter(Mandatory)][string]$Path)
  icacls $Path /inheritance:r | Out-Null
  icacls $Path /grant:r "Administrators:(F)" "SYSTEM:(F)" "Users:(R)" | Out-Null
  attrib +R $Path
}

function Ensure-IndexRefreshTask {
  param([string]$TaskName, [string]$Url, [string]$OutFile)

  $ps = "powershell.exe"
  $arg = "-NoProfile -ExecutionPolicy Bypass -Command `"try { iwr -UseBasicParsing -Uri '$Url' -OutFile '$OutFile' } catch { }`""

  schtasks /Delete /TN $TaskName /F 2>$null | Out-Null
  schtasks /Create /TN $TaskName /SC MINUTE /MO 1 /RU "SYSTEM" /RL HIGHEST `
    /TR "`"$ps`" $arg" | Out-Null
}

# --- INSTALL (choco) ---
Choco-Install -Pkgs @("git", "curl", "notepadplusplus", "xampp")

# --- CLONE / UPDATE ---
$GitExe = Resolve-GitExe

New-Item -ItemType Directory -Force -Path (Split-Path $WebRoot -Parent) | Out-Null

if (!(Test-Path $WebRoot)) {
  Write-Host "[*] Cloning repo -> $WebRoot"
  Invoke-Native -FilePath $GitExe -Args @("clone", $RepoUrl, $WebRoot)
} else {
  Write-Host "[*] Repo exists, pulling..."
  Invoke-Native -FilePath $GitExe -Args @("-C", $WebRoot, "pull")
}

# --- DOWNLOAD index.php (override) ---
Write-Host "[*] Downloading index.php -> $IndexPath"
New-Item -ItemType Directory -Force -Path $WebRoot | Out-Null

# unlock if exists
if (Test-Path $IndexPath) {
  attrib -R $IndexPath 2>$null
  icacls $IndexPath /reset 2>$null | Out-Null
  Remove-Item $IndexPath -Force -ErrorAction SilentlyContinue
}

Invoke-WebRequest -Uri $IndexUrl -OutFile $IndexPath -UseBasicParsing

# re-lock
Write-Host "[*] Locking index.php (ACL + ReadOnly)"
Lock-FileAclReadOnly -Path $IndexPath



# --- LOCK index.php ---
Write-Host "[*] Locking index.php (ACL + ReadOnly)"
Lock-FileAclReadOnly -Path $IndexPath

# --- OPTIONAL refresh task ---
if ($EnableRefreshTask) {
  Write-Host "[*] Creating scheduled task (minutely refresh)"
  Ensure-IndexRefreshTask -TaskName "CCDC-IndexRefresh" -Url $RefreshUrl -OutFile $IndexPath
}

# --- START APACHE (XAMPP) ---
if (Test-Path $ApacheExe) {
  Write-Host "[*] Starting Apache via XAMPP..."
  Push-Location $XamppDir
  cmd.exe /c $ApacheExe | Out-Null
  Pop-Location
} else {
  Write-Host "[!] XAMPP not found at $XamppDir. Search your XAMPP install path and update `$XamppDir."
}

Write-Host "[+] Done."
Write-Host "    Web path:  $WebRoot"
Write-Host "    index.php: $IndexPath"