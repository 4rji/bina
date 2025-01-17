#!/usr/bin/env bash

WEB_DIR="/etc/passwd"
HASH_FILE="/var/log/hash_file_passwd.txt"
TEMP_HASH_FILE="/tmp/hash_file_passwd_new.txt"





REPORT_FILE="/var/log/passwd_reports.txt"
HISTORICAL_FILE="/var/log/passwd_history.txt"
ALERT_FILE="$HOME/passwd_alerts.log"

FLAG_FILE="/tmp/hash_alert_triggered_passwd"
SCRIPT_PATH="$(realpath "$0")"

# Función para mostrar mensajes
echo_msg() {
  echo -e "\033[1;32m==============================================\033[0m"
  echo -e "\033[1;35m  $1\033[0m"
  echo -e "\033[1;34m==============================================\033[0m"
  echo ""
}

sudo touch "$HASH_FILE" "$REPORT_FILE" "$HISTORICAL_FILE"
sudo chmod 644 "$HASH_FILE" "$REPORT_FILE" "$HISTORICAL_FILE"

if [ ! -s "$HASH_FILE" ]; then
    echo_msg "Generating initial hashes..."
    sudo find "$WEB_DIR" -type f -exec sha256sum {} \; | sudo tee "$HASH_FILE" >/dev/null
    echo_msg "Hashes generated and saved to $HASH_FILE."
    exit 0
fi

sudo find "$WEB_DIR" -type f -exec sha256sum {} \; | sudo tee "$TEMP_HASH_FILE" >/dev/null

if ! sudo diff "$HASH_FILE" "$TEMP_HASH_FILE" >/dev/null; then
    echo_msg "\033[1;31mUnauthorized changes detected on $(date).\033[0m"
    if [[ ! -f "$FLAG_FILE" ]]; then
        {
            echo "$(date): Unauthorized changes detected."
            sudo diff "$HASH_FILE" "$TEMP_HASH_FILE"
        } | tee -a "$REPORT_FILE" "$HISTORICAL_FILE" "$ALERT_FILE" >/dev/null
        wall "ALERT: Unauthorized changes detected in $WEB_DIR. Check $ALERT_FILE for details.

        check:
        sudo cat $ALERT_FILE

        "
        
        sudo touch "$FLAG_FILE"
    fi

#aliased to xclip -sel clip sudo cat $ALERT_FILE 
#no se incorpora porque no funciona bien con crontab, pero si funcionaria normal

#sudo cat "$ALERT_FILE" | xclip -sel clip


else
    sudo rm -f "$FLAG_FILE"
    echo_msg "No changes detected on $(date)."
fi

sudo mv -f "$TEMP_HASH_FILE" "$HASH_FILE"

CRON_ENTRY="* * * * * /bin/bash -c '$SCRIPT_PATH; sleep 30; $SCRIPT_PATH'"
if ! sudo crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
    (sudo crontab -l 2>/dev/null; echo "$CRON_ENTRY") | sudo crontab -
    echo_msg "Cronjob agregado para ejecutar el script cada 30 segundos."
else
    echo_msg "El cronjob ya existe. No se realizaron cambios."
fi
