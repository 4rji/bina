#!/usr/bin/env bash
set -euo pipefail

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

CFG="/etc/timeshift/timeshift.json"

echo -e "${BLUE}[*] UUIDs disponibles en el sistema:${NC}"
echo -e "${BLUE}-----------------------------------${NC}"
sudo blkid
echo -e "${BLUE}-----------------------------------${NC}"
echo
echo -e "${YELLOW}[i] Copia el UUID del disco que quieres usar (ej. iSCSI /dev/sdb1)${NC}"
echo -e "${YELLOW}    y ejecútalo así:${NC}"
echo -e "${GREEN}    ./set-timeshift-uuid.sh <UUID>${NC}"
echo

UUID="${1:-}"

if [[ -z "$UUID" ]]; then
  echo -e "${RED}[!] No se proporcionó UUID${NC}"
  exit 1
fi

echo -e "${GREEN}[+] Usando UUID:${NC} ${BLUE}$UUID${NC}"
echo

sudo python3 - <<PY
import json

cfg="$CFG"
with open(cfg, "r", encoding="utf-8") as f:
    d=json.load(f)

d["backup_device_uuid"]="$UUID"
d["backup_device"]=""
d["backup_directory"]="/timeshift"
d["snapshot_device"]=""
d["snapshot_device_uuid"]=""

with open(cfg, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2)

print("[+] Timeshift configurado para usar UUID:", "$UUID")
PY

echo
echo -e "${GREEN}[+] Configuración aplicada correctamente.${NC}"
echo -e "${BLUE}[i] Verifica con:${NC}"
echo -e "${GREEN}    sudo timeshift --create --comments \"test uuid\" --tags D${NC}"
