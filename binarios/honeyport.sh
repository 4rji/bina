#!/bin/bash

# Name of the file to save IPs
output_file="block-ips.txt"

# Colors for output
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Initialize counter
counter=0

# Function to handle the interrupt signal (Ctrl+C)
cleanup() {
  echo -e "${BLUE}Exiting the script and closing connections...${NC}"
  exit 0
}

# Catch the interrupt signal (Ctrl+C)
trap cleanup SIGINT

# Infinite loop
while true; do
  echo -e "${BLUE}Waiting for connections on port 8080...${NC}"
  # Listen on port 8080 and process the output
  sudo nc -l -p 8080 -v 2>&1 | while read line; do
    # Extract the IP from lines that contain "connect to"
    if [[ $line == *"connect to"* ]]; then
      ip=$(echo $line | awk -F '[][]' '{print $4}')
      # Increment counter
      ((counter++))
      echo -e "${YELLOW}[$counter] Blocking IP: $ip${NC}"
      echo $ip >> $output_file
      # Block the IP using iptables
      sudo iptables -A INPUT -s $ip -j DROP
      echo -e "${RED}Blocked IP $ip for 20 seconds${NC}"
      # Unblock the IP after 20 seconds
      (sleep 20 && sudo iptables -D INPUT -s $ip -j DROP && echo -e "${WHITE}Unblocked IP $ip${NC}") &
    fi
  done
done

