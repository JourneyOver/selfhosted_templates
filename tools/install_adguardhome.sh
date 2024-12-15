# Set adguard service as default 53 DNS service on host

#!/bin/bash

# Step 1: Create the /etc/systemd/resolved.conf.d directory if it doesn't exist
CONF_DIR="/etc/systemd/resolved.conf.d"
if [ ! -d "$CONF_DIR" ]; then
    echo "Creating directory: $CONF_DIR"
    sudo mkdir -p "$CONF_DIR"
fi

# Step 2: Create the adguardhome.conf file with the required configuration
CONF_FILE="$CONF_DIR/adguardhome.conf"
echo "Creating configuration file: $CONF_FILE"
echo "[Resolve]" | sudo tee "$CONF_FILE" > /dev/null
echo "DNS=127.0.0.1" | sudo tee -a "$CONF_FILE" > /dev/null
echo "DNSStubListener=no" | sudo tee -a "$CONF_FILE" > /dev/null

# Step 3: Backup the existing /etc/resolv.conf and create a symbolic link
if [ -f "/etc/resolv.conf" ]; then
  echo "Backing up existing /etc/resolv.conf to /etc/resolv.conf.backup"
  sudo mv /etc/resolv.conf /etc/resolv.conf.backup
else
  echo "No existing /etc/resolv.conf to back up."
fi

echo "Creating symbolic link from /run/systemd/resolve/resolv.conf to /etc/resolv.conf"
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

# Step 4: Reload or restart systemd-resolved
echo "Reloading or restarting systemd-resolved"
sudo systemctl reload-or-restart systemd-resolved

# Final message
echo "Configuration complete."
