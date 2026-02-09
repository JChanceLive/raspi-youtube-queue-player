#!/bin/bash
# install.sh - One-command Raspberry Pi YouTube Queue Player setup
# Run ON the Pi: bash install.sh
set -e

# --- Configuration ---
QUEUE_DIR="${QUEUE_DIR:-$HOME/video-queue}"
CURRENT_USER=$(whoami)
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==========================================="
echo "  YouTube Queue Player - Installer"
echo "==========================================="
echo ""
echo "User:      $CURRENT_USER"
echo "Queue dir: $QUEUE_DIR"
echo "Repo:      $REPO_DIR"
echo ""

# --- Step 1: Pi Detection ---
echo "[1/10] Checking platform..."
if [ -f /sys/firmware/devicetree/base/model ]; then
    PI_MODEL=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
    echo "  Detected: $PI_MODEL"
else
    echo "  WARNING: Not running on a Raspberry Pi (or model file not found)"
    echo "  The installer will continue, but some features may not work."
    read -p "  Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# --- Step 2: Install Dependencies ---
echo ""
echo "[2/10] Installing dependencies..."
sudo apt update -qq
sudo apt install -y -qq mpv socat samba
echo "  Installing yt-dlp via pip (apt version is often outdated)..."
pip install --break-system-packages --upgrade yt-dlp 2>/dev/null || \
    pip install --upgrade yt-dlp 2>/dev/null || \
    pip3 install --break-system-packages --upgrade yt-dlp 2>/dev/null || \
    pip3 install --upgrade yt-dlp
echo "  Dependencies installed"

# --- Step 3: Create Directories ---
echo ""
echo "[3/10] Creating directories..."
mkdir -p "$QUEUE_DIR/scripts"
touch "$QUEUE_DIR/queue.txt"
echo "  Created $QUEUE_DIR"

# --- Step 4: Copy Scripts ---
echo ""
echo "[4/10] Copying scripts..."
cp "$REPO_DIR/scripts/"*.sh "$QUEUE_DIR/scripts/"
chmod +x "$QUEUE_DIR/scripts/"*.sh
echo "  Copied and made executable"

# --- Step 5: User Permissions ---
echo ""
echo "[5/10] Setting up user permissions..."
sudo usermod -aG video "$CURRENT_USER" 2>/dev/null || true
echo "  Added $CURRENT_USER to video group"

# --- Step 6: Systemd Service ---
echo ""
echo "[6/10] Setting up systemd service..."
SERVICE_FILE="/etc/systemd/system/video-player.service"
CURRENT_UID=$(id -u)
sed "s|__USER__|$CURRENT_USER|g; s|__QUEUE_DIR__|$QUEUE_DIR|g; s|__UID__|$CURRENT_UID|g" \
    "$REPO_DIR/config/video-player.service" | sudo tee "$SERVICE_FILE" > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable video-player.service
echo "  Service installed and enabled (starts on boot)"

# --- Step 7: MPV Config ---
echo ""
echo "[7/10] Configuring mpv..."
mkdir -p "$HOME/.config/mpv"
cp "$REPO_DIR/config/mpv.conf" "$HOME/.config/mpv/mpv.conf"
echo "  MPV cache settings configured"

# --- Step 8: Crontab (cache cleanup at 3 AM) ---
echo ""
echo "[8/10] Setting up cache cleanup cron..."
CRON_CMD="0 3 * * * $QUEUE_DIR/scripts/cleanup-cache.sh >> /tmp/cleanup-cache.log 2>&1"
if crontab -l 2>/dev/null | grep -q "cleanup-cache.sh"; then
    echo "  Cron entry already exists, skipping"
else
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo "  Added nightly cleanup at 3 AM"
fi

# --- Step 9: Shell Aliases ---
echo ""
echo "[9/10] Adding shell aliases..."
ALIAS_MARKER="# YouTube Queue Player aliases"
if grep -q "$ALIAS_MARKER" "$HOME/.bashrc" 2>/dev/null; then
    echo "  Aliases already exist, skipping"
else
    cat >> "$HOME/.bashrc" << EOF

$ALIAS_MARKER
alias pause='$QUEUE_DIR/scripts/pause.sh'
alias resume='$QUEUE_DIR/scripts/resume.sh'
alias skip='$QUEUE_DIR/scripts/skip.sh'
alias stop-player='sudo systemctl stop video-player'
alias start-player='sudo systemctl start video-player'
alias player-status='sudo systemctl status video-player'
alias queue='nano $QUEUE_DIR/queue.txt'
EOF
    echo "  Added aliases to ~/.bashrc"
fi

# --- Step 10: Samba Setup (Optional) ---
echo ""
echo "[10/10] Samba file sharing setup..."
read -p "  Set up Samba for network queue access? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SAMBA_MARKER="# YouTube Queue Player"
    if grep -q "$SAMBA_MARKER" /etc/samba/smb.conf 2>/dev/null; then
        echo "  Samba share already configured, skipping"
    else
        echo "" | sudo tee -a /etc/samba/smb.conf > /dev/null
        echo "$SAMBA_MARKER" | sudo tee -a /etc/samba/smb.conf > /dev/null
        sed "s|__USER__|$CURRENT_USER|g; s|__QUEUE_DIR__|$QUEUE_DIR|g" \
            "$REPO_DIR/config/smb.conf.template" | sudo tee -a /etc/samba/smb.conf > /dev/null
    fi

    echo "  Setting Samba password for $CURRENT_USER..."
    sudo smbpasswd -a "$CURRENT_USER"
    sudo systemctl restart smbd
    echo "  Samba configured and restarted"
else
    echo "  Skipped Samba setup (you can run install.sh again later)"
fi

# --- Summary ---
PI_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "==========================================="
echo "  Installation Complete!"
echo "==========================================="
echo ""
echo "  IP Address:  $PI_IP"
echo "  Queue File:  $QUEUE_DIR/queue.txt"
echo "  Samba URL:   smb://$PI_IP/video-queue"
echo ""
echo "  Commands (after reloading shell):"
echo "    pause        - Pause playback"
echo "    resume       - Resume playback"
echo "    skip         - Skip to next video"
echo "    stop-player  - Stop the player service"
echo "    start-player - Start the player service"
echo "    player-status - Check service status"
echo "    queue        - Edit queue file"
echo ""
echo "  Start now:  sudo systemctl start video-player"
echo "  Or reboot:  sudo reboot"
echo ""
echo "  Reload shell aliases:  source ~/.bashrc"
echo "==========================================="
