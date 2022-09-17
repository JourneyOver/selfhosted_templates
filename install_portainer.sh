#!/bin/bash

sudo docker network create bunni_network
# Portainer Business Edition
sudo docker pull portainer/portainer-ee:latest || error "Failed to pull latest Portainer docker image!"
sudo docker run -d --network=bunni_network -e TZ=America/Chicago -p 9000:9000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ee:latest || error "Failed to run Portainer docker image!"

# Portainer Community Edition
#sudo docker pull portainer/portainer-ce:latest || error "Failed to pull latest Portainer docker image!"
#sudo docker run -d --network=bunni_network -e TZ=America/Chicago -p 9000:9000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest || error "Failed to run Portainer docker image!"
