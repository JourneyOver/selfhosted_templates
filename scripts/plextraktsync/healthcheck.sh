#!/bin/sh
# /mnt/Docker/Apps/PlexTraktSync/healthcheck.sh

start_epoch=$(stat -c %Y /proc/1 2>/dev/null || echo 0)

# Temp file for log snippet (avoids subshell exit code issues in pipes)
tail -n 200 /app/config/plextraktsync.log > /tmp/check.log 2>/dev/null

unhealthy=0
while IFS= read -r line || [ -n "$line" ]; do
  if echo "$line" | grep -q -E "(Unauthorized - OAuth must be provided|Max token refresh attempts reached\. Manual intervention required\.|400 - Unable to refresh expired OAuth token|Unprocessable Entity - validation errors)"; then
    ts=$(echo "$line" | cut -c1-19)
    ts="${ts%,*}"  # Strip ,mmm if present
    parsed_epoch=$(date -d "$ts" +%s 2>/dev/null)
    if [ -n "$parsed_epoch" ] && [ "$parsed_epoch" -ge "$start_epoch" ]; then
      unhealthy=1
      break
    fi
  fi
done < /tmp/check.log

rm -f /tmp/check.log

# Exit status for Docker HEALTHCHECK
if [ $unhealthy -eq 1 ]; then
  exit 1
fi

exit 0