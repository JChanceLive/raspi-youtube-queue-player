# Troubleshooting

Common issues and their fixes, gathered from real setup experience.

## 1. No Audio Over HDMI

**Symptom:** Video plays on TV but there's no sound.

**Fix:** Force audio output to HDMI:

```bash
sudo raspi-config
# Advanced Options > Audio > Force HDMI
```

Or set it directly:

```bash
sudo amixer cset numid=3 2
```

If you have a Pi 4/5 with two HDMI ports, make sure you're using **HDMI 0** (the one closest to the power port).

## 2. Video Stuttering / Buffering

**Symptom:** Video plays but stutters, freezes, or has poor quality.

**Fixes:**

- The player caps at **720p** by default. Pi 3 can't handle 1080p well. This is already configured.
- Check your Wi-Fi signal. Ethernet is much more reliable for streaming.
- The mpv cache settings in `~/.config/mpv/mpv.conf` should help:
  ```
  cache=yes
  demuxer-max-bytes=50M
  demuxer-max-back-bytes=25M
  ```
- For Pi 3, stick to H.264 content. AV1 and VP9 may be too demanding.

## 3. HLS Keepalive Warnings

**Symptom:** Console shows warnings like `hls: keepalive_timeout` or similar HLS messages.

**Fix:** These are harmless. They're just mpv/yt-dlp logging HTTP keep-alive behavior. The video plays fine despite them.

## 4. Pause/Resume Not Working

**Symptom:** Running `pause` or `resume` command does nothing.

**Fixes:**

- Make sure **socat** is installed: `sudo apt install socat`
- Check that mpv is actually running: `player-status`
- Verify the socket exists: `ls -la /tmp/mpv-socket`
- If the socket is stale (mpv crashed), restart the service: `start-player`

## 5. [PLAYED] Marker Issues

**Symptom:** Videos replay, or the `[PLAYED]` marker isn't added.

**How it works:** The player marks videos as `[PLAYED]` *before* playing them. This prevents replays if mpv crashes mid-video.

**If a video replayed:**
- Check `queue.txt` for duplicate URLs
- Make sure the URL format matches exactly (no extra spaces or parameters)

**To replay a video:** Remove the `[PLAYED] ` prefix from the line in `queue.txt`.

## 6. Service Won't Start

**Symptom:** `player-status` shows the service as failed.

**Debug steps:**

```bash
# Check logs
sudo journalctl -u video-player -n 50

# Check if DISPLAY is set
sudo systemctl show video-player | grep Environment

# Try running manually
DISPLAY=:0 ~/video-queue/scripts/player.sh
```

**Common causes:**
- Missing `DISPLAY=:0` in the service file
- User not in the `video` group: `sudo usermod -aG video $(whoami)` then reboot
- Scripts not executable: `chmod +x ~/video-queue/scripts/*.sh`

## 7. Samba Connection Refused

**Symptom:** Can't connect from Mac Finder via `smb://raspberrypi.local/video-queue`.

**Fixes:**

- Set the Samba password (required even if your Linux password is set):
  ```bash
  sudo smbpasswd -a $(whoami)
  ```
- Restart Samba:
  ```bash
  sudo systemctl restart smbd
  ```
- Check Samba is running:
  ```bash
  sudo systemctl status smbd
  ```
- Verify the share exists:
  ```bash
  testparm -s 2>/dev/null | grep video-queue
  ```

**Mac-specific:** If Finder hangs, try connecting from Terminal first:
```bash
open "smb://raspberrypi.local/video-queue"
```

## 8. yt-dlp Errors

**Symptom:** Videos fail to play with yt-dlp errors in the logs.

**Fix:** yt-dlp needs frequent updates because YouTube changes its API:

```bash
pip install --upgrade yt-dlp
```

Or if using pip3:
```bash
pip3 install --upgrade yt-dlp
```

**Common yt-dlp errors:**
- `ERROR: [youtube] ...: Sign in to confirm your age` - Age-restricted content won't work without cookies
- `ERROR: [youtube] ...: Video unavailable` - Video was deleted or is private
- `ERROR: unable to download webpage` - Network issue, check your connection

## 9. SD Card Full

**Symptom:** Pi runs out of disk space.

**Fix:** The installer sets up a nightly cleanup cron job at 3 AM. If your card is already full:

```bash
# Manual cleanup
rm -rf ~/.cache/yt-dlp/*
find /tmp -name "*mpv*" -delete
find /tmp -name "*yt-dlp*" -delete

# Check disk space
df -h /
```

**Verify cron is running:**
```bash
crontab -l | grep cleanup
```

You should see: `0 3 * * * /home/.../scripts/cleanup-cache.sh`

## General Debug Tips

**Check service status:**
```bash
sudo systemctl status video-player
```

**View live logs:**
```bash
sudo journalctl -u video-player -f
```

**Test mpv directly:**
```bash
DISPLAY=:0 mpv --fullscreen "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

**Test yt-dlp directly:**
```bash
yt-dlp -F "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

**Check what's in the queue:**
```bash
grep -v '^\[PLAYED\]' ~/video-queue/queue.txt | grep -v '^#' | grep -v '^$'
```
