# Full Setup Guide

Complete walkthrough from unboxing a Raspberry Pi to a working YouTube queue player on your TV.

## What You Need

- **Raspberry Pi 3B+ or newer** (Pi 4/5 also work great)
- **microSD card** (16GB minimum, 32GB recommended)
- **Power supply** (USB-C for Pi 4/5, micro-USB for Pi 3)
- **HDMI cable** (micro-HDMI adapter for Pi 4/5)
- **TV with HDMI input**
- **Another computer** (Mac/PC/Linux for initial setup)
- **Wi-Fi or Ethernet** connection

## Step 1: Flash Raspberry Pi OS

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/) on your Mac/PC
2. Insert your microSD card
3. Open Raspberry Pi Imager:
   - **OS**: Raspberry Pi OS (32-bit) - the default "Recommended" option
   - **Storage**: Your microSD card
4. Click the **gear icon** (or Ctrl+Shift+X) for advanced options:
   - **Enable SSH**: Yes (use password authentication)
   - **Set username and password**: Pick something you'll remember (e.g., `jopi` / your password)
   - **Configure Wi-Fi**: Enter your network name and password
   - **Set locale**: Your timezone
5. Click **Write** and wait for it to finish

## Step 2: First Boot

1. Insert the microSD into your Pi
2. Connect the HDMI cable to your TV
3. Plug in the power supply
4. Wait 1-2 minutes for first boot

## Step 3: Connect via SSH

From your Mac/PC terminal:

```bash
ssh jopi@raspberrypi.local
```

Replace `jopi` with the username you set. If `.local` doesn't work, find the Pi's IP address from your router's admin page and use that instead.

## Step 4: System Update

```bash
sudo apt update && sudo apt upgrade -y
```

This can take 5-10 minutes on first run.

## Step 5: Install the Player

```bash
git clone https://github.com/JChanceLive/raspi-youtube-queue-player.git
cd raspi-youtube-queue-player
bash install.sh
```

The installer will:
- Install mpv, yt-dlp, socat, and samba
- Create the queue directory (`~/video-queue/`)
- Set up the systemd service (auto-start on boot)
- Configure mpv cache settings
- Add a nightly cache cleanup cron job
- Add shell aliases for easy control
- Optionally configure Samba for network access

**Say "y" to the Samba prompt** if you want to add videos from your Mac via Finder.

## Step 6: Test It

Add a video to the queue:

```bash
echo "https://www.youtube.com/watch?v=dQw4w9WgXcQ" >> ~/video-queue/queue.txt
```

Start the player:

```bash
sudo systemctl start video-player
```

Your TV should start playing the video within a few seconds.

## Step 7: Set Up Samba Access (Mac)

If you enabled Samba during install:

1. Open **Finder** on your Mac
2. Press **Cmd+K** (Connect to Server)
3. Enter: `smb://raspberrypi.local/video-queue`
4. Enter the username and password you set during Samba setup
5. You should see the `queue.txt` file

Now you can edit `queue.txt` directly from your Mac - just paste YouTube URLs, one per line.

## Step 8: Verify Auto-Start

Reboot the Pi:

```bash
sudo reboot
```

After it boots back up (give it 1-2 minutes), if there are URLs in `queue.txt`, it should start playing automatically.

Check the service status:

```bash
ssh jopi@raspberrypi.local "sudo systemctl status video-player"
```

## Step 9 (Optional): Static IP

If `raspberrypi.local` is unreliable, set a static IP:

```bash
sudo nmcli con mod "preconfigured" ipv4.addresses 10.0.0.25/24
sudo nmcli con mod "preconfigured" ipv4.gateway 10.0.0.1
sudo nmcli con mod "preconfigured" ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli con mod "preconfigured" ipv4.method manual
sudo nmcli con up "preconfigured"
```

Adjust the IP addresses to match your network. Common patterns:
- `192.168.1.x` or `192.168.0.x` for most routers
- `10.0.0.x` for some networks

## You're Done!

Your Pi will now:
- Start the player on boot
- Watch `queue.txt` for new URLs
- Play videos on your TV via HDMI
- Clean up its cache every night at 3 AM
- Share the queue folder via Samba for easy access

Next: Add some videos and enjoy!
