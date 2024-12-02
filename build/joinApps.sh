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

# Process each JSON file in the apps folder
for app in template/apps/*.json; do
  # Check if the app file exists and is not empty
  if [[ -s "$app" ]]; then
    echo "Processing $app..."

    # Read and validate JSON content
    appjson=$(jq -e '.' < "$app" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
      echo "Invalid JSON in $app. Skipping..."
      continue
    fi

    # Add the sequential "id" for v3
    appjson_v3=$(jq --argjson id "$id_counter" '. + {id: $id}' <<< "$appjson")
    ((id_counter++))

    # Add the app JSON to v2 and v3 templates
    json_v2=$(jq --argjson newApp "$appjson" '.templates += [$newApp]' <<< "$json_v2")
    json_v3=$(jq --argjson newApp "$appjson_v3" '.templates += [$newApp]' <<< "$json_v3")
  else
    echo "Skipping empty or non-existent file: $app"
  fi
done

# Sort templates by title (case-insensitive) and save to the respective files
if echo "$json_v2" | jq --indent 2 '.templates |= sort_by(.title | ascii_upcase)' > "$template_v2"; then
  echo "v2 Template generation complete. Output saved to $template_v2"
else
  echo "Failed to write the v2 JSON to $template_v2"
  exit 1
fi

if echo "$json_v3" | jq --indent 2 '.templates |= sort_by(.title | ascii_upcase)' > "$template_v3"; then
  echo "v3 Template generation complete. Output saved to $template_v3"
else
  echo "Failed to write the v3 JSON to $template_v3"
  exit 1
fi
