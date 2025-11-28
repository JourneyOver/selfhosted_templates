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

# Create the Docker network
create_network

log "Network setup completed successfully!"