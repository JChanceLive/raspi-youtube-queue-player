#!/bin/bash
# pause.sh - Pause the currently playing video via MPV IPC socket
MPV_SOCKET="${MPV_SOCKET:-/tmp/mpv-socket}"
echo '{"command": ["set_property", "pause", true]}' | socat - "$MPV_SOCKET"
