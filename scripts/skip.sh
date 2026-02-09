#!/bin/bash
# skip.sh - Skip to next video by quitting current mpv instance
# The player.sh loop will automatically pick up the next URL
MPV_SOCKET="${MPV_SOCKET:-/tmp/mpv-socket}"

if [ ! -S "$MPV_SOCKET" ]; then
    echo "No video is currently playing"
    exit 1
fi

echo '{"command": ["quit"]}' | socat - "$MPV_SOCKET" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Skipped"
else
    echo "Failed to skip (mpv may not be running)"
    exit 1
fi
