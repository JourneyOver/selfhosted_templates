#!/bin/bash

# Define the initial JSON structures for version 2 and version 3 templates
json_v2='{"version":"2","templates":[]}'
json_v3='{"version":"3","templates":[]}'

# Template output files
template_v2='template/portainer-v2.json'
template_v3='template/portainer-v3.json'

# Get the script's directory
scriptDir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$scriptDir/.." || { echo "Failed to change directory."; exit 1; }

# Initialize the ID counter for v3
id_counter=1

# Function to log messages
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to validate JSON
validate_json() {
  jq -e '.' < "$1" > /dev/null 2>&1
  return $?
}

# Function to add app JSON to templates
add_app_to_templates() {
  local appjson="$1"
  local appjson_v3=$(jq --argjson id "$id_counter" '. + {id: $id}' <<< "$appjson")
  ((id_counter++))

  json_v2=$(jq --argjson newApp "$appjson" '.templates += [$newApp]' <<< "$json_v2")
  json_v3=$(jq --argjson newApp "$appjson_v3" '.templates += [$newApp]' <<< "$json_v3")
}

# Function to save JSON to file
save_json() {
  local json="$1"
  local output_file="$2"
  local version="$3"

  if echo "$json" | jq --indent 2 '.templates |= sort_by(.title | ascii_upcase)' > "$output_file"; then
    log "$version Template generation complete. Output saved to $output_file"
  else
    log "Failed to write the $version JSON to $output_file"
    exit 1
  fi
}

# Process each JSON file in the apps folder
for app in template/apps/*.json; do
  # Check if the app file exists and is not empty
  if [[ -s "$app" ]]; then
    log "Processing $app..."

    # Read and validate JSON content
    if validate_json "$app"; then
      appjson=$(jq -e '.' < "$app")
      add_app_to_templates "$appjson"
    else
      log "Invalid JSON in $app. Skipping..."
      continue
    fi
  else
    log "Skipping empty or non-existent file: $app"
  fi
done

# Save the final JSON structures to their respective files
save_json "$json_v2" "$template_v2" "v2"
save_json "$json_v3" "$template_v3" "v3"