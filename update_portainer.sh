#!/bin/bash

portainer_pid=`docker ps -a | grep portainer | awk '{print $1}'`
portainer_name=`docker ps -a | grep portainer | awk '{print $2}'`

sudo docker stop $portainer_pid || error "Failed to stop portainer!"
sudo docker rm $portainer_pid || error "Failed to remove portainer container!"
sudo docker rmi $portainer_name || error "Failed to remove/untag images from the container!"
# Portainer Business Edition
sudo docker run -d --network=bunni_network -p 9000:9000 -p 9443:9443 --name=portainer --restart=always --health-cmd='wget --no-verbose --tries=3 --spider http://localhost:9000/api/system/status || exit 1' --health-interval=60s --health-retries=3 --health-timeout=5s --health-start-period=20s -v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ee:alpine-sts || error "Failed to execute newer version of Portainer!"

# Portainer Community Edition
#sudo docker run -d --network=bunni_network -p 9000:9000 -p 9443:9443 --name=portainer --restart=always --health-cmd='wget --no-verbose --tries=3 --spider http://localhost:9000/api/system/status || exit 1' --health-interval=60s --health-retries=3 --health-timeout=5s --health-start-period=20s -v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:alpine-sts || error "Failed to execute newer version of Portainer!"
