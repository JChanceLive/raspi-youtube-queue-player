# Raspberry Pi YouTube Queue Player

Turn your Raspberry Pi into a YouTube TV player. Drop video URLs into a text file, and they play automatically on your TV via HDMI.

## Features

- **Queue-based playback** - Add YouTube URLs to a text file, they play in order
- **Auto-start on boot** - Plug in your Pi and it starts playing
- **Remote queue management** - Edit the queue from your Mac/PC via Samba file sharing
- **Playback controls** - Pause, resume, skip via simple commands
- **Comment support** - Use `#` for comments and notes in your queue
- **Auto-cleanup** - Nightly cache clearing prevents SD card from filling up
- **One-command install** - Clone and run `install.sh`

## Quick Start

SSH into your Raspberry Pi, then:

```bash
git clone https://github.com/JChanceLive/raspi-youtube-queue-player.git
cd raspi-youtube-queue-player
bash install.sh
```

The installer handles everything: dependencies, systemd service, aliases, and optionally Samba.

## Add Videos

**On the Pi:**
```bash
echo "https://www.youtube.com/watch?v=dQw4w9WgXcQ" >> ~/video-queue/queue.txt
```

**From your Mac (via Samba):**
1. Open Finder
2. Press `Cmd+K`
3. Enter `smb://raspberrypi.local/video-queue`
4. Open `queue.txt` in any text editor
5. Paste YouTube URLs (one per line)

## Control Playback

After installation, these commands are available on the Pi:

| Command | Action |
|---------|--------|
| `pause` | Pause current video |
| `resume` | Resume playback |
| `skip` | Skip to next video |
| `replay` | Re-queue all (or specific) played videos |
| `stop-player` | Stop the player service |
| `start-player` | Start the player service |
| `player-status` | Check if player is running |
| `queue` | Edit queue file in nano |

**Remote control via SSH:**
```bash
ssh jopi@raspberrypi.local "~/video-queue/scripts/pause.sh"
```

## How It Works

```
                    ┌─────────────┐
                    │   Your TV   │
                    │  (via HDMI) │
                    └──────▲──────┘
                           │
                    ┌──────┴──────┐
                    │ Raspberry Pi│
                    │             │
                    │  mpv ◄─ yt-dlp
                    │   ▲        │
                    │   │        │
                    │  player.sh │
                    │   ▲        │
                    │   │        │
                    │ queue.txt  │
                    └──────▲──────┘
                           │ Samba
                    ┌──────┴──────┐
                    │  Your Mac   │
                    │  (Finder)   │
                    └─────────────┘
```

1. **player.sh** watches `queue.txt` for new URLs
2. When it finds one, it marks it `[PLAYED]` and passes it to **mpv**
3. **mpv** uses **yt-dlp** to stream the video to your TV via HDMI
4. When the video ends, it picks up the next URL
5. **Samba** shares the queue folder so you can add URLs from any device

## Queue File Format

```
# My Watch Queue
# Lines starting with # are ignored
# Blank lines are ignored too

https://www.youtube.com/watch?v=dQw4w9WgXcQ
https://www.youtube.com/watch?v=jNQXAC9IVRw
[PLAYED] https://www.youtube.com/watch?v=9bZkp7q19f0
```

## Updating

After pulling changes from this repo, push them to your Pi:

```bash
./deploy.sh
```

Or with custom connection details:

```bash
./deploy.sh user@pi-hostname /path/to/queue-dir
```

## Uninstalling

On the Pi:
```bash
bash uninstall.sh
```

This removes the service, scripts, cron entry, and aliases. Your `queue.txt` is preserved.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues like no audio, video stuttering, and Samba connection problems.

## Documentation

- [Full Setup Guide](docs/SETUP.md) - From unboxing to working player
- [Architecture](docs/ARCHITECTURE.md) - System diagram and component details
- [Troubleshooting](docs/TROUBLESHOOTING.md) - All known issues and fixes

## Hardware

- Raspberry Pi 3B+ or newer
- microSD card (16GB+)
- HDMI cable
- Power supply
- TV with HDMI input

## License

MIT - See [LICENSE](LICENSE)
