#!/bin/sh
# /mnt/Docker/Apps/PlexTraktSync/healthcheck.sh

LOG_FILE="/app/config/plextraktsync.log"

# How much recent log history to inspect.
LOG_TAIL=1000

# OAuth refresh-loop protection.
#
# A normal refresh should look like:
#   OAuth token has expired, refreshing now...
#   OAuth token successfully refreshed, valid until ...
#
# Mark unhealthy if:
#   - the refresh message occurs this many times without a success, OR
#   - a refresh has been pending this many seconds without a success.
OAUTH_MAX_ATTEMPTS=3
OAUTH_STUCK_SECONDS=120

SNAPSHOT=$(mktemp /tmp/plextraktsync-health.XXXXXX) || exit 1
ERRORS=$(mktemp /tmp/plextraktsync-errors.XXXXXX) || {
    rm -f "$SNAPSHOT"
    exit 1
}

trap 'rm -f "$SNAPSHOT" "$ERRORS"' EXIT HUP INT TERM

# Get container start time.
start_epoch=$(stat -c %Y /proc/1 2>/dev/null || echo 0)
now_epoch=$(date +%s)

# Take one snapshot so every check operates on the same log data.
tail -n "$LOG_TAIL" "$LOG_FILE" 2>/dev/null > "$SNAPSHOT"

# ---------------------------------------------------------------------------
# Error Classification Taxonomy
#
# Fatal:
#   - OAuth authentication/refresh failures
#   - Invalid/revoked grants
#   - Validation errors
#   - Persistent network failures
#
# Transient:
#   - Rate limiting
#   - A single OAuth refresh notice
#   - Progress messages
#
# Stalled transient:
#   - Repeated OAuth refresh notices without a successful refresh
#   - OAuth refresh remaining pending for too long
# ---------------------------------------------------------------------------

ERR_PATTERN="(Unauthorized - OAuth must be provided|Max token refresh attempts reached|400 - Unable to refresh expired OAuth token|Unprocessable Entity - validation errors|NameResolutionError.*plex\.direct|OAuth token refresh failed|invalid_grant|Max retries exceeded with url)"

IGNORE_PATTERN='"message":"Progress is|Rate Limit Exceeded for plextraktsync\.trakt\.TraktApi\.'

# ---------------------------------------------------------------------------
# 1. Check explicit fatal errors
# ---------------------------------------------------------------------------

grep -E "$ERR_PATTERN" "$SNAPSHOT" 2>/dev/null | \
grep -Ev "$IGNORE_PATTERN" > "$ERRORS"

while IFS= read -r line; do
    [ -z "$line" ] && continue

    # First 19 chars: YYYY-MM-DD HH:MM:SS
    ts=$(printf '%s\n' "$line" | cut -c1-19)
    parsed_epoch=$(date -d "$ts" +%s 2>/dev/null)

    # Ignore errors from before this container instance started.
    if [ -n "$parsed_epoch" ] && [ "$parsed_epoch" -ge "$start_epoch" ]; then
        echo "UNHEALTHY: fatal PlexTraktSync error detected:"
        echo "$line"
        exit 1
    fi
done < "$ERRORS"

# ---------------------------------------------------------------------------
# 2. Detect an OAuth refresh loop / stuck refresh
# ---------------------------------------------------------------------------

oauth_attempts=0
oauth_pending_since=0

while IFS= read -r line; do
    [ -z "$line" ] && continue

    ts=$(printf '%s\n' "$line" | cut -c1-19)
    parsed_epoch=$(date -d "$ts" +%s 2>/dev/null)

    # Only consider timestamped entries from this container instance.
    if [ -z "$parsed_epoch" ] || [ "$parsed_epoch" -lt "$start_epoch" ]; then
        continue
    fi

    # A successful refresh clears the pending/stuck state.
    if printf '%s\n' "$line" | grep -Fq \
        "OAuth token successfully refreshed"; then

        oauth_attempts=0
        oauth_pending_since=0
        continue
    fi

    # An expiry/refresh notice starts or increments the pending state.
    if printf '%s\n' "$line" | grep -Fq \
        "OAuth token has expired, refreshing now..."; then

        oauth_attempts=$((oauth_attempts + 1))

        if [ "$oauth_pending_since" -eq 0 ]; then
            oauth_pending_since=$parsed_epoch
        fi
    fi
done < "$SNAPSHOT"

# Repeated refresh attempts without ever seeing a successful refresh.
if [ "$oauth_attempts" -ge "$OAUTH_MAX_ATTEMPTS" ]; then
    echo "UNHEALTHY: OAuth refresh loop detected."
    echo "Refresh attempts without success: $oauth_attempts"
    exit 1
fi

# A single refresh attempt that simply hangs indefinitely.
if [ "$oauth_pending_since" -gt 0 ]; then
    oauth_pending_age=$((now_epoch - oauth_pending_since))

    if [ "$oauth_pending_age" -ge "$OAUTH_STUCK_SECONDS" ]; then
        echo "UNHEALTHY: OAuth refresh appears stuck."
        echo "No successful refresh after ${oauth_pending_age} seconds."
        exit 1
    fi
fi

exit 0
