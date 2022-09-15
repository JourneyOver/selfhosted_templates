#!/bin/bash

# Blank portainer template
json='{"version":"2","templates":[]}'

# Main Template
template='template-stack/portainer-v2-only-stacks.json'

# Run script from base directory
scriptDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$scriptDir/.." || exit

# Parsing all json files in apps folder
for app in template-stack/apps/*.json; do
  # Output app name to easy debug
  echo "adding $app to template..."

  appjson=$( cat "$app" )

  if [[ -n "$appjson" ]]; then
    json=$( echo "$json" | jq --argjson newApp "$appjson" '.templates += [$newApp]' )
  fi

  # clean variables before next loop
  unset appjson
done

# Create Templates
echo "$json" | jq --indent 2 '.templates |= sort_by(.title | ascii_upcase)' > "$template"
