#!/bin/bash

# Blank portainer template
json='{"version":"2","templates":[]}'

# Main Template
template='template/portainer-v2.json'

# Get the script's directory
scriptDir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$scriptDir/.." || exit

# Loop through and process JSON files in apps folder
for app in template/apps/*.json; do
  # Output app name for debugging
  echo "Adding $app to template..."

  appjson=$(<"$app")

  # Append to JSON if content is non-empty
  if [[ -n "$appjson" ]]; then
    json=$(jq --argjson newApp "$appjson" '.templates += [$newApp]' <<< "$json")
  fi
done

# Sort templates by title and save the final JSON to the template file
echo "$json" | jq --indent 2 '.templates |= sort_by(.title | ascii_upcase)' > "$template"
