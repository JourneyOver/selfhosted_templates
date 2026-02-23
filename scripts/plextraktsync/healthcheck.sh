#!/bin/sh
# /mnt/Docker/Apps/PlexTraktSync/healthcheck.sh

LOG_FILE="/app/config/plextraktsync.log"
TEMP_FILE="/tmp/check.log"

# Get container start time (creation time of PID 1)
start_epoch=$(stat -c %Y /proc/1 2>/dev/null || echo 0)

# Define Critical Errors Regex
# 1. Unauthorized/Token issues
# 2. Validation errors (Unprocessable Entity)
# 3. Connection issues (NameResolutionError)
ERR_PATTERN="(Unauthorized - OAuth must be provided|Max token refresh attempts reached|400 - Unable to refresh expired OAuth token|Unprocessable Entity - validation errors|NameResolutionError.*plex\.direct)"

# Processing Pipeline:
# 1. Read last 200 lines.
# 2. Filter IN lines matching the critical error pattern.
# 3. Filter OUT the specific harmless "Progress is" bug using grep -v.
# 4. Save potential candidates to a temp file.
tail -n 200 "$LOG_FILE" 2>/dev/null | \
grep -E "$ERR_PATTERN" | \
grep -v '"message":"Progress is' > "$TEMP_FILE"

unhealthy=0

# Loop through the filtered potential errors
while IFS= read -r line; do
  if [ -n "$line" ]; then
    # Extract timestamp (First 19 chars: YYYY-MM-DD HH:MM:SS)
    ts=$(echo "$line" | cut -c1-19)
    
    # Convert log timestamp to epoch
    parsed_epoch=$(date -d "$ts" +%s 2>/dev/null)
    
    # Check if the error occurred AFTER the container started
    if [ -n "$parsed_epoch" ] && [ "$parsed_epoch" -ge "$start_epoch" ]; then
      unhealthy=1
      break
    fi
  fi
done < "$TEMP_FILE"

rm -f "$TEMP_FILE"

if [ "$unhealthy" -eq 1 ]; then
  exit 1
fi

exit 0