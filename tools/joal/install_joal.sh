#!/bin/bash

function error {
  echo -e "\\e[91m$1\\e[39m"
  exit 1
}

echo "Creating directories..."
sudo mkdir -p /portainer/Files/AppData/Joal/config/torrents/archived || error "Failed to create Joal torrents folder!"
sudo mkdir -p /portainer/Files/AppData/Joal/config/clients || error "Failed to create Joal clients folder!"
echo "Downloading joal config file"
sudo wget -O /portainer/Files/AppData/Joal/config/config.json https://raw.githubusercontent.com/anthonyraymond/joal/master/resources/config.json || error "Failed to download joal config!"
echo "Changing owner of config folder and files to ${USER}"
sudo chown -R ${USER}:${USER} /portainer/Files/AppData/Joal/config || error "Failed to make ${USER} owner of Joal config folder!"
echo "Running qbit client maker to get the latest release of qbittorrent"
cd ./qbit_client_maker
sh ./qBittorrent.sh
echo "Setup complete. You can now install Joal using the App Template."
