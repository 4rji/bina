# Wazuh Agent install (Windows) - PowerShell
# Run PowerShell as Administrator

$WazuhVer = "4.13.1-1"
$Group    = "default"
$Url      = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WazuhVer.msi"
$OutFile  = Join-Path $env:TEMP "wazuh-agent-$WazuhVer.msi"

$Manager  = Read-Host "Wazuh Manager IP"
$Agent    = Read-Host "Agent name"

Write-Host "`nDownloading: $Url"
Invoke-WebRequest -Uri $Url -OutFile $OutFile

Write-Host "Installing MSI..."
$msiArgs = @(
  "/i", "`"$OutFile`"",
  "/qn",
  "WAZUH_MANAGER=$Manager",
  "WAZUH_AGENT_NAME=$Agent",
  "WAZUH_AGENT_GROUP=$Group"
)

Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -NoNewWindow

Write-Host "Starting service..."
Start-Service -Name "Wazuh" -ErrorAction SilentlyContinue
Start-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue

# Show status (whichever exists)
Get-Service -Name "Wazuh","WazuhSvc" -ErrorAction SilentlyContinue | Format-Table Status,Name,DisplayName

Write-Host "`nDone."
