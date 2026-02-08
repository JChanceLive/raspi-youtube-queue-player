#!/bin/bash
# skip.sh - Skip to next video by quitting current mpv instance
# The player.sh loop will automatically pick up the next URL
MPV_SOCKET="${MPV_SOCKET:-/tmp/mpv-socket}"
echo '{"command": ["quit"]}' | socat - "$MPV_SOCKET"
