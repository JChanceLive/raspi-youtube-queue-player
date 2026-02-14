#!/bin/bash
# deploy.sh - Push script updates FROM Mac TO Pi
# Usage: ./deploy.sh [user@host] [queue-dir]

PI_HOST="${1:-youruser@raspberrypi.local}"
QUEUE_DIR="${2:-/home/$(echo "$PI_HOST" | cut -d@ -f1)/video-queue}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Deploying to $PI_HOST ==="
echo "Queue dir: $QUEUE_DIR"
echo ""

# Test SSH connection
echo "Testing connection..."
if ! ssh -o ConnectTimeout=5 "$PI_HOST" "echo 'Connected'" 2>/dev/null; then
    echo "ERROR: Cannot connect to $PI_HOST"
    echo "  - Is the Pi on the network?"
    echo "  - Try: ssh $PI_HOST"
    exit 1
fi

# Copy scripts
echo "Copying scripts..."
scp "$REPO_DIR/scripts/"*.sh "$PI_HOST:$QUEUE_DIR/scripts/"

# Make executable
echo "Setting permissions..."
ssh "$PI_HOST" "chmod +x $QUEUE_DIR/scripts/*.sh"

# Update service file with Wayland support
echo "Updating service file..."
PI_USER=$(echo "$PI_HOST" | cut -d@ -f1)
PI_UID=$(ssh "$PI_HOST" "id -u")
ssh "$PI_HOST" "sed 's|__USER__|$PI_USER|g; s|__QUEUE_DIR__|$QUEUE_DIR|g; s|__UID__|$PI_UID|g' /dev/stdin | sudo tee /etc/systemd/system/video-player.service > /dev/null && sudo systemctl daemon-reload" < "$REPO_DIR/config/video-player.service"

# Restart service
echo "Restarting service..."
ssh "$PI_HOST" "sudo systemctl restart video-player"

# Show status
echo ""
echo "=== Deploy Complete ==="
ssh "$PI_HOST" "sudo systemctl status video-player --no-pager -l" 2>/dev/null || true
echo ""
echo "Done!"
