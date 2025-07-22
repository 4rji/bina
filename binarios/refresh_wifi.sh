#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then
  echo "Run as root or with sudo"; exit 1
fi

sudo rfkill unblock wifi
ip link set wlan0 down
sleep 2
ip link set wlan0 up
systemctl restart wpa_supplicant@wlan0.service
systemctl restart NetworkManager.service
echo "WiFi reset completed successfully."
