#!/bin/bash
# player.sh - Main queue processor loop
# Watches queue.txt for YouTube URLs and plays them via mpv + yt-dlp
# Marks played videos with [PLAYED] prefix

QUEUE_DIR="${QUEUE_DIR:-$HOME/video-queue}"
QUEUE_FILE="$QUEUE_DIR/queue.txt"
MPV_SOCKET="${MPV_SOCKET:-/tmp/mpv-socket}"

# Ensure queue file exists
touch "$QUEUE_FILE"

echo "=== YouTube Queue Player ==="
echo "Queue file: $QUEUE_FILE"
echo "MPV socket: $MPV_SOCKET"
echo "Waiting for videos..."

while true; do
    # Get next unplayed URL (skip blank lines, comments, and [PLAYED] entries)
    NEXT_URL=$(grep -v '^\[PLAYED\]' "$QUEUE_FILE" | grep -v '^#' | grep -v '^[[:space:]]*$' | head -n 1)

    if [ -n "$NEXT_URL" ]; then
        # Trim whitespace
        NEXT_URL=$(echo "$NEXT_URL" | xargs)

        echo ""
        echo ">>> Now playing: $NEXT_URL"

        # Mark as played BEFORE starting (so it won't replay on crash)
        sed -i "s|^${NEXT_URL}$|[PLAYED] ${NEXT_URL}|" "$QUEUE_FILE"

        # Play with mpv + yt-dlp, using IPC socket for controls
        mpv --input-ipc-server="$MPV_SOCKET" \
            --ytdl-format="bestvideo[height<=720]+bestaudio/best[height<=720]" \
            --fullscreen \
            --no-terminal \
            "$NEXT_URL"

        echo ">>> Finished: $NEXT_URL"
    else
        # No videos in queue - wait and check again
        sleep 5
    fi
done
