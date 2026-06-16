#!/bin/sh
# /mnt/Docker/Apps/PlexTraktSync/healthcheck.sh

LOG_FILE="/app/config/plextraktsync.log"
TEMP_FILE="/tmp/check.log"

# Get container start time (creation time of PID 1)
start_epoch=$(stat -c %Y /proc/1 2>/dev/null || echo 0)

# Error Classification Taxonomy:
#   Fatal (immediately unhealthy):
#     - OAuth token refresh failures (token expired/revoked/invalid grant)
#     - Persistent connection failures (max retries, DNS resolution)
#     - Validation errors from upstream API
#   Transient (filtered out, self-healing):
#     - Rate limiting notices (API throttle, auto-retries)
#     - Token expiry notices (refresh is in progress)
#     - Progress messages (harmless noise)
# Define Critical Errors Regex
# 1. Authentication failures — OAuth token expired/revoked, refresh failures, invalid grants
# 2. Validation errors — Unprocessable Entity responses
# 3. Connection exhaustion — Name resolution failures, max network retries exceeded
ERR_PATTERN="(Unauthorized - OAuth must be provided|Max token refresh attempts reached|400 - Unable to refresh expired OAuth token|Unprocessable Entity - validation errors|NameResolutionError.*plex\.direct|OAuth token refresh failed|invalid_grant|Max retries exceeded with url)"

# Processing Pipeline:
# 1. Read last 200 lines of the log.
# 2. Filter IN lines matching fatal error pattern (auth, validation, connection).
# 3. Filter OUT known transient patterns (refresh notices, rate limits, progress).
# 4. Save remaining candidates to a temp file.
tail -n 200 "$LOG_FILE" 2>/dev/null | \
grep -E "$ERR_PATTERN" | \
grep -Ev '"message":"Progress is|OAuth token has expired, refreshing now\.\.\.|Rate Limit Exceeded for plextraktsync\.trakt\.TraktApi\.' > "$TEMP_FILE"

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
