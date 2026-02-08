#!/bin/bash
# uninstall.sh - Remove YouTube Queue Player from Pi
# Run ON the Pi: bash uninstall.sh
# NOTE: Preserves queue.txt and does NOT remove dependencies (mpv, yt-dlp, etc.)

QUEUE_DIR="${QUEUE_DIR:-$HOME/video-queue}"

echo "==========================================="
echo "  YouTube Queue Player - Uninstaller"
echo "==========================================="
echo ""
echo "This will remove:"
echo "  - Systemd service (video-player.service)"
echo "  - Scripts ($QUEUE_DIR/scripts/)"
echo "  - Cron entry (nightly cleanup)"
echo "  - Shell aliases"
echo ""
echo "This will NOT remove:"
echo "  - queue.txt (your queue is preserved)"
echo "  - Dependencies (mpv, yt-dlp, socat, samba)"
echo "  - MPV config (~/.config/mpv/mpv.conf)"
echo "  - Samba share config"
echo ""
read -p "Continue with uninstall? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Stop and disable service
echo ""
echo "Removing systemd service..."
sudo systemctl stop video-player 2>/dev/null || true
sudo systemctl disable video-player 2>/dev/null || true
sudo rm -f /etc/systemd/system/video-player.service
sudo systemctl daemon-reload
echo "  Done"

# Remove scripts (keep queue.txt)
echo "Removing scripts..."
rm -rf "$QUEUE_DIR/scripts"
echo "  Done (queue.txt preserved)"

# Remove cron entry
echo "Removing cron entry..."
if crontab -l 2>/dev/null | grep -q "cleanup-cache.sh"; then
    crontab -l 2>/dev/null | grep -v "cleanup-cache.sh" | crontab -
    echo "  Done"
else
    echo "  No cron entry found"
fi

# Remove shell aliases
echo "Removing shell aliases..."
ALIAS_MARKER="# YouTube Queue Player aliases"
if grep -q "$ALIAS_MARKER" "$HOME/.bashrc" 2>/dev/null; then
    sed -i "/$ALIAS_MARKER/,/^alias queue=/d" "$HOME/.bashrc"
    echo "  Done"
else
    echo "  No aliases found"
fi

echo ""
echo "==========================================="
echo "  Uninstall Complete"
echo "==========================================="
echo "  Queue file preserved: $QUEUE_DIR/queue.txt"
echo "  To fully remove: rm -rf $QUEUE_DIR"
echo "==========================================="
