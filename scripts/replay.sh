#!/bin/bash
# replay.sh - Remove [PLAYED] tags to re-queue videos
# Usage: replay        - Unmark ALL played videos
#        replay [url]  - Unmark a specific video

QUEUE_DIR="${QUEUE_DIR:-$HOME/video-queue}"
QUEUE_FILE="$QUEUE_DIR/queue.txt"

if [ ! -f "$QUEUE_FILE" ]; then
    echo "Queue file not found: $QUEUE_FILE"
    exit 1
fi

if [ -z "$1" ]; then
    # Remove ALL [PLAYED] tags
    count=$(grep -c '^\[PLAYED\]' "$QUEUE_FILE" 2>/dev/null || echo 0)
    sed -i 's/^\[PLAYED\] //' "$QUEUE_FILE"
    echo "Unmarked $count videos - queue is ready to replay"
else
    # Remove [PLAYED] from specific URL
    target="[PLAYED] $1"
    if grep -qF "$target" "$QUEUE_FILE"; then
        awk -v target="$target" -v url="$1" \
            '{if ($0 == target) print url; else print}' \
            "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
        echo "Unmarked: $1"
    else
        echo "URL not found as played: $1"
        exit 1
    fi
fi
