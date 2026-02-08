#!/bin/bash
# resume.sh - Resume the paused video via MPV IPC socket
MPV_SOCKET="${MPV_SOCKET:-/tmp/mpv-socket}"
echo '{"command": ["set_property", "pause", false]}' | socat - "$MPV_SOCKET"
