# Architecture

## System Diagram

```
┌─────────────────────────────────────────────────────┐
│                    YOUR TV                          │
│                  (HDMI input)                       │
└────────────────────────▲────────────────────────────┘
                         │ HDMI
┌────────────────────────┴────────────────────────────┐
│                  RASPBERRY PI                       │
│                                                     │
│  ┌─────────────┐    ┌─────────┐    ┌──────────┐   │
│  │  player.sh  │───>│   mpv   │───>│  HDMI    │   │
│  │  (loop)     │    │         │    │  output  │   │
│  └──────▲──────┘    └────▲────┘    └──────────┘   │
│         │                │                         │
│         │           ┌────┴────┐                    │
│  ┌──────┴──────┐    │  yt-dlp │                    │
│  │  queue.txt  │    │(stream) │                    │
│  └──────▲──────┘    └─────────┘                    │
│         │                                          │
│  ┌──────┴──────┐    ┌─────────────────────┐       │
│  │   Samba     │    │  IPC Socket          │       │
│  │   share     │    │  /tmp/mpv-socket     │       │
│  └──────▲──────┘    └──────▲──────────────┘       │
│         │                  │                       │
│         │           ┌──────┴──────┐                │
│         │           │ pause.sh    │                │
│         │           │ resume.sh   │                │
│         │           │ skip.sh     │                │
│         │           └─────────────┘                │
│  ┌──────┴───────────────────────────────────┐     │
│  │          systemd (video-player.service)   │     │
│  │          cron (cleanup-cache.sh @ 3AM)    │     │
│  └───────────────────────────────────────────┘     │
└────────────────────────▲────────────────────────────┘
                         │ SMB / SSH
┌────────────────────────┴────────────────────────────┐
│                   YOUR MAC/PC                       │
│                                                     │
│  Finder (smb://pi/video-queue) - edit queue.txt    │
│  Terminal (ssh) - pause, resume, skip, status       │
└─────────────────────────────────────────────────────┘
```

## Components

### player.sh (Queue Processor)

The main loop that runs as a systemd service. It:

1. Reads `queue.txt` line by line
2. Skips lines starting with `[PLAYED]`, `#`, or blank lines
3. Takes the first valid URL
4. Marks it as `[PLAYED]` (before playing, so crashes don't replay)
5. Launches `mpv` with the URL
6. Waits for mpv to finish, then loops back

When no URLs are available, it sleeps 5 seconds and checks again.

### mpv (Video Player)

Plays video on the HDMI-connected display. Key config:

- `--ytdl-format="bestvideo[height<=720]+bestaudio/best[height<=720]"` - Caps at 720p (Pi 3 can't handle higher)
- `--fullscreen` - Full screen on TV
- `--input-ipc-server=/tmp/mpv-socket` - IPC socket for remote control
- Cache settings in `~/.config/mpv/mpv.conf` for smoother streaming

### yt-dlp (YouTube Downloader)

Called by mpv internally to resolve YouTube URLs into streamable video. Installed via pip for the latest version (the apt package is often months behind).

### queue.txt (Queue File)

Plain text file, one URL per line. Supports:

```
# Comments (lines starting with #)

https://youtube.com/watch?v=...     # Pending video
[PLAYED] https://youtube.com/...    # Already played
```

### IPC Socket (/tmp/mpv-socket)

Unix socket that mpv listens on for JSON IPC commands. The control scripts send commands through it via `socat`:

- `pause.sh` - Sets pause property to true
- `resume.sh` - Sets pause property to false
- `skip.sh` - Sends quit command (player.sh picks up next URL)

### Samba (File Sharing)

Shares `~/video-queue/` as a network folder. Accessible from Mac via `smb://raspberrypi.local/video-queue`. This lets you edit `queue.txt` from Finder without SSH.

### systemd (Service Manager)

`video-player.service` runs `player.sh` as a system service:

- Starts automatically on boot
- Restarts on failure (10 second delay)
- Waits for network before starting
- Sets `DISPLAY=:0` for HDMI output

### cron (Scheduled Cleanup)

`cleanup-cache.sh` runs at 3 AM daily:

- Clears `~/.cache/yt-dlp/`
- Removes old `/tmp/*mpv*` and `/tmp/*yt-dlp*` files
- Prevents SD card from filling up

## File Locations on Pi

```
~/video-queue/
├── queue.txt              # The queue (add URLs here)
└── scripts/
    ├── player.sh          # Main loop
    ├── pause.sh           # Pause control
    ├── resume.sh          # Resume control
    ├── skip.sh            # Skip control
    └── cleanup-cache.sh   # Cache cleaner

~/.config/mpv/
└── mpv.conf               # MPV cache settings

/etc/systemd/system/
└── video-player.service   # Systemd unit

/tmp/
└── mpv-socket             # IPC socket (runtime only)
```

## Data Flow

1. **User adds URL** to `queue.txt` (via Samba, SSH, or directly)
2. **player.sh** detects the new URL on its next 5-second check
3. **player.sh** marks the URL as `[PLAYED]` in `queue.txt`
4. **player.sh** launches `mpv` with the URL
5. **mpv** calls **yt-dlp** to resolve the URL to a stream
6. **yt-dlp** returns the stream URL to **mpv**
7. **mpv** plays the video on the **TV** via **HDMI**
8. User can **pause/resume/skip** via IPC socket commands
9. When the video ends, **mpv** exits and **player.sh** loops back to step 2
