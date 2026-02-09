#!/bin/bash
# pause.sh - Pause the currently playing video via MPV IPC socket
MPV_SOCKET="${MPV_SOCKET:-/tmp/mpv-socket}"

if [ ! -S "$MPV_SOCKET" ]; then
    echo "No video is currently playing"
    exit 1
fi

echo '{"command": ["set_property", "pause", true]}' | socat - "$MPV_SOCKET" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Paused"
else
    echo "Failed to pause (mpv may not be running)"
    exit 1
fi
