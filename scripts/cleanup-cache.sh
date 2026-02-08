#!/bin/bash
# cleanup-cache.sh - Clean yt-dlp and mpv temp files
# Designed to run via cron (e.g., daily at 3 AM)

echo "[$(date)] Starting cache cleanup..."

# Clear yt-dlp cache
if [ -d "$HOME/.cache/yt-dlp" ]; then
    rm -rf "$HOME/.cache/yt-dlp"/*
    echo "  Cleared yt-dlp cache"
fi

# Clear old mpv temp files
find /tmp -name "*mpv*" -mtime +1 -delete 2>/dev/null
find /tmp -name "*yt-dlp*" -mtime +1 -delete 2>/dev/null
echo "  Cleared old temp files"

echo "[$(date)] Cache cleanup complete"
