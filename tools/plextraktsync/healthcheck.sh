#!/bin/sh
# /mnt/Docker/Apps/PlexTraktSync/healthcheck.sh

start_epoch=$(stat -c %Y /proc/1 2>/dev/null || echo 0)

tail -n 200 /app/config/plextraktsync.log | awk -v start="$start_epoch" '
function parse_epoch(line) {
    ts = substr(line, 1, 19);
    gsub(/[-]/, " ", ts);
    return mktime(ts);
}

{
    line = $0

    if (match(line, /Unauthorized - OAuth must be provided/) ||
        match(line, /Max token refresh attempts reached. Manual intervention required./) ||
        match(line, /400 - Unable to refresh expired OAuth token/)) {
        epoch = parse_epoch(line)
        if (epoch >= start) {
            exit 1
        }
    }
}

END {
    exit 0
}
' > /dev/null 2>&1

exit $?