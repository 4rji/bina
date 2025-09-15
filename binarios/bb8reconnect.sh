#!/bin/bash
set -euo pipefail
IF="bb8"

# lock para evitar solapes
exec 9>/var/lock/wg-restart.lock
flock -n 9 || exit 0

sudo wg-quick down "$IF" 2>/dev/null || true
sudo wg-quick up "$IF"

