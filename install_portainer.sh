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

# Function to create a Docker network
create_network() {
  if ! sudo docker network inspect bunni_network > /dev/null 2>&1; then
    log "Creating Docker network: bunni_network..."
    sudo docker network create bunni_network || error "Failed to create Docker network!"
  else
    log "Docker network 'bunni_network' already exists."
  fi
}

# Function to pull a Docker image
pull_image() {
  local image="$1"
  log "Pulling Docker image: $image..."
  sudo docker pull "$image" || error "Failed to pull Docker image: $image"
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
PORTTAINER_IMAGE="docker.io/portainer/portainer-ee:alpine-sts"  # Business Edition
# PORTTAINER_IMAGE="docker.io/portainer/portainer-ce:alpine-sts"  # Community Edition

# Create the Docker network
create_network

# Pull the Portainer Docker image
pull_image "$PORTTAINER_IMAGE"

# Run the Portainer container
run_portainer "$PORTTAINER_IMAGE"

log "Portainer setup completed successfully!"