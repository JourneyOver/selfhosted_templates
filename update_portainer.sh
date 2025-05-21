#!/bin/bash

# Function to log messages
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to handle errors
error() {
  log "ERROR: $1"
  exit 1
}

# Function to get the Portainer container ID and image name
get_portainer_info() {
  local portainer_info=$(docker ps -a --filter "name=portainer" --format "{{.ID}} {{.Image}}")
  if [[ -z "$portainer_info" ]]; then
    log "No Portainer container found."
    return 1
  fi
  echo "$portainer_info"
}

# Function to stop and remove the Portainer container
stop_and_remove_portainer() {
  local portainer_pid="$1"
  local portainer_name="$2"

  log "Stopping Portainer container with ID: $portainer_pid..."
  sudo docker stop "$portainer_pid" || error "Failed to stop Portainer container!"

  log "Removing Portainer container with ID: $portainer_pid..."
  sudo docker rm "$portainer_pid" || error "Failed to remove Portainer container!"

  log "Removing/Untagging Portainer image: $portainer_name..."
  sudo docker rmi "$portainer_name" || error "Failed to remove/untag Portainer image!"
}

# Function to run the Portainer container
run_portainer() {
  local image="$1"
  log "Starting Portainer container with image: $image..."
  sudo docker run -d \
    --network=bunni_network \
    -p 9000:9000 \
    -p 9443:9443 \
    --name=portainer \
    --restart=always \
    --health-cmd='wget --no-verbose --tries=3 --spider http://localhost:9000/api/system/status || exit 1' \
    --health-interval=60s \
    --health-retries=3 \
    --health-timeout=5s \
    --health-start-period=20s \
    -v /etc/timezone:/etc/timezone:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    "$image" || error "Failed to run Portainer container with image: $image"
}

# Main script logic

# Define the Docker image for Portainer (Business Edition or Community Edition)
PORTAINER_IMAGE="docker.io/portainer/portainer-ee:alpine-sts"  # Business Edition
# PORTAINER_IMAGE="docker.io/portainer/portainer-ce:alpine-sts"  # Community Edition

# Get the Portainer container ID and image name
portainer_info=$(get_portainer_info)
if [[ -n "$portainer_info" ]]; then
  portainer_pid=$(echo "$portainer_info" | awk '{print $1}')
  portainer_name=$(echo "$portainer_info" | awk '{print $2}')

  # Stop and remove the existing Portainer container
  stop_and_remove_portainer "$portainer_pid" "$portainer_name"
fi

# Run the Portainer container with the specified image
run_portainer "$PORTAINER_IMAGE"

log "Portainer update completed successfully!"
