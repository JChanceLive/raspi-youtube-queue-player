#!/bin/bash
# player.sh - Main queue processor loop (v2)
# Watches queue.txt for YouTube URLs and plays them via mpv + yt-dlp
# Includes: Wayland auto-detect, cascade protection, socket cleanup

QUEUE_DIR="${QUEUE_DIR:-$HOME/video-queue}"
QUEUE_FILE="$QUEUE_DIR/queue.txt"
MPV_SOCKET="${MPV_SOCKET:-/tmp/mpv-socket}"
LOG_FILE="$QUEUE_DIR/player.log"

# Protection thresholds
MIN_PLAY_SECONDS=5          # Under this = "didn't really play"
MAX_RAPID_FAILURES=3        # After this many, skip the video
FAILURE_BACKOFF=30          # Seconds to wait after max failures

# Ensure queue file exists
touch "$QUEUE_FILE"

consecutive_failures=0

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Auto-detect Wayland display if not set
detect_wayland() {
    if [ -n "$WAYLAND_DISPLAY" ]; then
        return 0
    fi

    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    for sock in "$runtime_dir"/wayland-[0-9]*; do
        if [ -S "$sock" ]; then
            export WAYLAND_DISPLAY=$(basename "$sock")
            log "Auto-detected Wayland: $WAYLAND_DISPLAY"
            return 0
        fi
    done

    log "WARNING: No Wayland display found, falling back to DISPLAY=$DISPLAY"
    return 1
}

# Remove stale mpv socket if no mpv is running
cleanup_socket() {
    if [ -e "$MPV_SOCKET" ] && ! pgrep -x mpv > /dev/null 2>&1; then
        rm -f "$MPV_SOCKET"
        log "Cleaned up stale socket"
    fi
}

# Mark a URL as [PLAYED] using exact string match (no regex issues)
mark_played() {
    local url="$1"
    awk -v url="$url" '{if ($0 == url) print "[PLAYED] " $0; else print}' \
        "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

# Remove [PLAYED] prefix to allow retry
unmark_played() {
    local url="$1"
    local target="[PLAYED] $url"
    awk -v target="$target" -v url="$url" \
        '{if ($0 == target) {print url; found=1} else print}' \
        "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

# --- Startup ---
detect_wayland
log "=== YouTube Queue Player v2 ==="
log "Queue file: $QUEUE_FILE"
log "MPV socket: $MPV_SOCKET"
log "Display: WAYLAND=$WAYLAND_DISPLAY DISPLAY=$DISPLAY"
log "Waiting for videos..."

while true; do
    # Get next unplayed URL (skip blank lines, comments, and [PLAYED] entries)
    NEXT_URL=$(grep -v '^\[PLAYED\]' "$QUEUE_FILE" | grep -v '^#' | grep -v '^[[:space:]]*$' | head -n 1)

    if [ -n "$NEXT_URL" ]; then
        # Trim whitespace
        NEXT_URL=$(echo "$NEXT_URL" | xargs)

        log ">>> Now playing: $NEXT_URL"

        # Clean up stale socket before starting
        cleanup_socket

        # Mark as played BEFORE starting (prevents replay on crash)
        mark_played "$NEXT_URL"

        # Record start time
        START_TIME=$(date +%s)

        # Play with mpv + yt-dlp
        # Use ALSA HDMI directly (bypasses PipeWire session issues)
        mpv --input-ipc-server="$MPV_SOCKET" \
            --ytdl-format="bestvideo[height<=720]+bestaudio/best[height<=720]" \
            --audio-device=alsa/hdmi:CARD=vc4hdmi,DEV=0 \
            --fullscreen \
            --no-terminal \
            "$NEXT_URL"
        MPV_EXIT=$?

        END_TIME=$(date +%s)
        PLAY_DURATION=$((END_TIME - START_TIME))

        # Clean up socket after mpv exits
        rm -f "$MPV_SOCKET"

        if [ $MPV_EXIT -ne 0 ] && [ $PLAY_DURATION -lt $MIN_PLAY_SECONDS ]; then
            # mpv failed quickly - not a real play
            consecutive_failures=$((consecutive_failures + 1))
            log ">>> FAILED (exit=$MPV_EXIT, ${PLAY_DURATION}s, streak=$consecutive_failures): $NEXT_URL"

            if [ $consecutive_failures -ge $MAX_RAPID_FAILURES ]; then
                # Too many failures in a row - skip this video and back off
                log ">>> Skipping after $MAX_RAPID_FAILURES failures, backing off ${FAILURE_BACKOFF}s"
                sleep $FAILURE_BACKOFF
                consecutive_failures=0
            else
                # Undo [PLAYED] so it retries next loop
                unmark_played "$NEXT_URL"
                sleep 3
            fi
        else
            # Successful play or user skip (exit 0 + any duration, or long play)
            consecutive_failures=0
            log ">>> Finished (exit=$MPV_EXIT, ${PLAY_DURATION}s): $NEXT_URL"
        fi
    else
        # No videos in queue - wait and check again
        sleep 5
    fi
done
