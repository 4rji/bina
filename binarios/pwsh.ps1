# disk_check.ps1

$THRESHOLD = 90

$DISK_USAGE = df -h / | Select-Object -Skip 1 | ForEach-Object {
    ($_.ToString() -split '\s+')[4] -replace '%',''
}

$DISK_USAGE = [int]$DISK_USAGE

if ($DISK_USAGE -ge $THRESHOLD) {
    Write-Output "Disk space is running low! Current usage is $DISK_USAGE%"
} else {
    Write-Output "Disk space is still within acceptable limits. Current usage is $DISK_USAGE%"
}
