#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Define the entry you want to add or modify (IP and hostname)
IP_ADDRESS="10.43.63.55"
HOSTNAME="mlflow-tracking.local"

# Ask the user what action they want to perform
echo "Choose an action:"
echo "1) Update hostname of an existing IP"
echo "2) Update IP of an existing hostname"
echo "3) Add a new entry"
echo "4) Add another hostname to an existing IP"
echo "5) Delete an entry"
read -p "Enter choice (1/2/3/4/5): " choice

case $choice in
  1)
    # Update hostname for the given IP address
    if grep -q "^$IP_ADDRESS " /etc/hosts; then
      echo "IP address $IP_ADDRESS found, updating hostname..."
      sed -i.bak "/^$IP_ADDRESS /d" /etc/hosts
      echo "$IP_ADDRESS $HOSTNAME" | tee -a /etc/hosts > /dev/null
      echo "Hostname updated successfully."
    else
      echo "IP address $IP_ADDRESS not found."
    fi
    ;;
  2)
    # Update IP for the given hostname
    if grep -q " $HOSTNAME$" /etc/hosts; then
      echo "Hostname $HOSTNAME found, updating IP address..."
      sed -i.bak "/ $HOSTNAME$/d" /etc/hosts
      echo "$IP_ADDRESS $HOSTNAME" | tee -a /etc/hosts > /dev/null
      echo "IP address updated successfully."
    else
      echo "Hostname $HOSTNAME not found."
    fi
    ;;
  3)
    # Add a new entry
    echo "Adding new entry..."
    echo "$IP_ADDRESS $HOSTNAME" | tee -a /etc/hosts > /dev/null
    echo "Entry added successfully."
    ;;
  4)
    # Add another hostname to an existing IP address
    if grep -q "^$IP_ADDRESS " /etc/hosts; then
      echo "IP address $IP_ADDRESS found. Adding another hostname..."
      sed -i.bak "/^$IP_ADDRESS /s/$/ $HOSTNAME/" /etc/hosts
      echo "New hostname added to the IP address."
    else
      echo "IP address $IP_ADDRESS not found."
    fi
    ;;
  5)
    # Delete an entry
    if grep -q "^$IP_ADDRESS $HOSTNAME$" /etc/hosts; then
      sed -i.bak "/^$IP_ADDRESS $HOSTNAME$/d" /etc/hosts
      echo "Entry with IP $IP_ADDRESS and hostname $HOSTNAME deleted successfully."
    else
      echo "No matching entry with IP $IP_ADDRESS and hostname $HOSTNAME found."
    fi
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Flush DNS cache (Linux)
sudo systemd-resolve --flush-caches
echo "DNS cache flushed successfully."

# Show the current state of /etc/hosts
cat /etc/hosts
