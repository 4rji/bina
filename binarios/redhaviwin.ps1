#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# --- CONFIG ---
$PackagesWinget = @(
  "Git.Git",
  "Notepad++.Notepad++",
  "curl.curl",
  "ApacheFriends.Xampp"   # Alternativa simple para PHP+Apache (XAMPP)
  # Si prefieres Apache "puro", usa Chocolatey (abajo) o un MSI específico.
)

$RepoUrl   = "https://github.com/banago/simple-php-website.git"
$WebRoot   = "C:\www\simple-php-website"
$IndexUrl  = "https://raw.githubusercontent.com/4rji/ccdc/main/index.php"
$IndexPath = Join-Path $WebRoot "index.php"

function Test-Command($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Install-WithWinget {
  param([string[]]$Pkgs)
  foreach ($p in $Pkgs) {
    Write-Host "[*] Installing (winget): $p"
    winget install --id $p --silent --accept-package-agreements --accept-source-agreements
  }
}

function Ensure-Choco {
  if (Test-Command choco) { return }
  Write-Host "[*] Installing Chocolatey..."
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  iex ((New-Object Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1"))
}

function Install-WithChoco {
  param([string[]]$Pkgs)
  Ensure-Choco
  foreach ($p in $Pkgs) {
    Write-Host "[*] Installing (choco): $p"
    choco install -y $p
  }
}

# --- PICK A PACKAGE MANAGER ---
if (Test-Command winget) {
  Install-WithWinget -Pkgs $PackagesWinget
} else {
  # Fallback: Chocolatey (ajusta a tu gusto)
  Install-WithChoco -Pkgs @("git", "notepadplusplus", "curl")
  # Para Apache/PHP en choco podrías usar: "apache-httpd" y "php" (según disponibilidad en tu entorno)
}

# --- CLONE REPO ---
function Invoke-Native {
  param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [Parameter(Mandatory=$true)][string[]]$Args
  )

  $out = & $FilePath @Args 2>&1
  $code = $LASTEXITCODE

  # imprime salida normal
  if ($out) { $out | ForEach-Object { Write-Host $_ } }

  if ($code -ne 0) {
    throw "Native command failed ($code): $FilePath $($Args -join ' ')"
  }
}

# --- CLONE / UPDATE REPO ---

# resolve git path (after installs)
$GitExe = (Get-Command git -ErrorAction Stop).Source

if (!(Test-Path $WebRoot)) {
  Write-Host "[*] Cloning repo -> $WebRoot"
  Invoke-Native -FilePath $GitExe -Args @("clone", $RepoUrl, $WebRoot)
} else {
  Write-Host "[*] Repo path exists, pulling latest..."
  Invoke-Native -FilePath $GitExe -Args @("-C", $WebRoot, "pull")
}


# --- DOWNLOAD index.php ---
Write-Host "[*] Downloading index.php -> $IndexPath"
New-Item -ItemType Directory -Force -Path $WebRoot | Out-Null
Invoke-WebRequest -Uri $IndexUrl -OutFile $IndexPath -UseBasicParsing

# --- LOCK FILE (read-only via ACL, stronger than attrib) ---
Write-Host "[*] Setting ACL: deny write to non-admin users on index.php"
icacls $IndexPath /inheritance:r | Out-Null
icacls $IndexPath /grant:r "Administrators:(F)" "SYSTEM:(F)" "Users:(R)" | Out-Null

# Optional: also set ReadOnly attribute (cosmetic)
attrib +R $IndexPath

# --- START APACHE SERVICE (if installed as a Windows service) ---
# XAMPP doesn't install "Apache2.4" as a normal service unless you do it via its control panel.
# If you have a service, this will try to start it.
$svc = Get-Service | Where-Object { $_.Name -match "Apache|httpd" } | Select-Object -First 1
if ($svc) {
  Write-Host "[*] Starting service: $($svc.Name)"
  Start-Service $svc.Name -ErrorAction SilentlyContinue
  Set-Service  $svc.Name -StartupType Automatic -ErrorAction SilentlyContinue
} else {
  Write-Host "[!] No Apache/httpd service found. If you're using XAMPP, start Apache from XAMPP Control Panel."
}

Write-Host "[+] Done."
Write-Host "    Web path: $WebRoot"
Write-Host "    index.php: $IndexPath"
