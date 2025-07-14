#!/bin/bash

# ============================================
# Script to manage the Logitech logs folder:
# - Shows useful commands to block/unblock writing to the logs
# - Shows the current size of the logs folder
# - Asks if you want to delete its contents
# ============================================

echo ""
echo "_________________________________________________________"
echo ""

echo -e "\033[1;36m  Useful commands:  \033[0m"
echo ""
echo -e "\033[1;33m  Block writing:  \033[0m"
echo ""
echo -e "\033[1;32m  sudo chmod -R 000 ~/Library/Logs/xlog_logitech  \033[0m"
echo ""
echo -e "\033[1;33m  Restore permissions:  \033[0m"
echo ""
echo -e "\033[1;32m  sudo chmod -R 755 ~/Library/Logs/xlog_logitech  \033[0m"

echo ""
echo "_________________________________________________________"
echo ""

DIR="$HOME/Library/Logs/xlog_logitech"

if [ -d "$DIR" ]; then
  SIZE=$(du -sh "$DIR" | cut -f1)
  echo ""
  echo -e "\033[1;35m  Folder size: $SIZE  \033[0m"
  echo ""

  echo ""
  echo "_________________________________________________________"
  echo ""

  read -p $'\033[1;36m  Do you want to delete all contents of '"$DIR"$'? (y/N): \033[0m' CONFIRM

  if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
    sudo find "$DIR" -type f -delete
    sudo find "$DIR" -type d -empty -delete

    echo ""
    echo "_________________________________________________________"
    echo ""

    echo_msg() {
        echo "=============================================="
        echo "$1"
        echo "=============================================="
    }

    echo -e "\033[1;31m"
    echo_msg "  Contents deleted.  "
    echo -e "\033[0m"

    echo ""
    echo "_________________________________________________________"
    echo ""

  else
    echo ""
    echo -e "\033[1;33m  Operation cancelled.  \033[0m"
    echo ""
  fi
else
  echo ""
  echo -e "\033[1;31m  Folder does not exist: $DIR  \033[0m"
  echo ""
fi