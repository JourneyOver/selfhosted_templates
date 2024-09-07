#!/bin/bash

sudo docker network create bunni_network
# Portainer Business Edition
sudo docker pull portainer/portainer-ee:alpine-sts || error "Failed to pull latest Portainer docker image!"
sudo docker run -d --network=bunni_network -p 9000:9000 -p 9443:9443 --name=portainer --restart=always --health-cmd='wget --no-verbose --tries=3 --spider http://localhost:9000/api/system/status || exit 1' --health-interval=60s --health-retries=3 --health-timeout=5s --health-start-period=20s -v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ee:alpine-sts || error "Failed to run Portainer docker image!"

# Portainer Community Edition
#sudo docker pull portainer/portainer-ce:alpine-sts || error "Failed to pull latest Portainer docker image!"
#sudo docker run -d --network=bunni_network -p 9000:9000 -p 9443:9443 --name=portainer --restart=always --health-cmd='wget --no-verbose --tries=3 --spider http://localhost:9000/api/system/status || exit 1' --health-interval=60s --health-retries=3 --health-timeout=5s --health-start-period=20s -v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:alpine-sts || error "Failed to run Portainer docker image!"
