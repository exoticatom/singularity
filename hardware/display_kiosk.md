# Display & Kiosk Setup

> ← Back to **[Hardware README](README.md)**

The singularity brewing controller uses a dedicated touchscreen display running in kiosk mode, showing the [Home Assistant](../home_assistant.md) singularity dashboard full-screen.

---

## Display — Joy-IT RB-LCD10-2

| Parameter | Value |
|---|---|
| Model | Joy-IT RB-LCD10-2 |
| Screen size | 10.1" IPS |
| Resolution | 1280 × 800 |
| Video input | HDMI (full-size) |
| Touch interface | USB (touch controller) |
| Power input | 12V DC |
| Aspect ratio | 16:10 |
| Panel type | IPS |

**Connections to Pi 4:**
- HDMI → Pi 4 HDMI port (full-size HDMI cable)
- USB-A → Pi 4 USB port (touch controller)
- 12V DC → dedicated 12V supply

> Tested and confirmed working with the singularity dashboard as the default display.

---

## Kiosk Computer — Raspberry Pi 4 (2GB)

| Parameter | Value |
|---|---|
| Model | Raspberry Pi 4 |
| RAM | 2GB |
| OS | Raspberry Pi OS Lite (64-bit) |
| Hostname | `singularity-kiosk-wifi` |
| Username | `<your-username>` (local admin) |
| Mode | Kiosk — Chromium browser, full-screen |
| Default page | singularity Home Assistant dashboard |
| Update method | OTA / SSH — no physical access needed |

**Connections:**
- HDMI out → Joy-IT RB-LCD10-2
- USB-A → Joy-IT touch controller
- USB-C → 5V power supply
- WiFi → same network as Home Assistant Pi

---

## Physical Setup

The display and Pi 4 are separate from the main electrical box:

```
┌─────────────────────────────────────────────┐
│         Electrical Box                      │
│                                             │
│  ESP32-S3  │  ADS1115  │  Level Shifter     │
│  Breadboard│  DAC      │  Other modules     │
└─────────────────────────────────────────────┘
                    ↕ WiFi / network
┌─────────────────────────────────────────────┐
│         Display Unit                        │
│                                             │
│  Joy-IT RB-LCD10-2 (10.1" IPS touch)       │
│         │ HDMI + USB                        │
│  Raspberry Pi 4 (2GB) — kiosk mode         │
│         → singularity dashboard             │
└─────────────────────────────────────────────┘
```

The Pi 4 is mounted behind or beside the display panel, off the main A4 fiberglass board. This keeps heat, thick cables (HDMI + USB + power) and the Pi itself separate from the sensor/logic board.

---

## Pi Setup Configuration

**Hostname:** `singularity-kiosk-wifi`
**Local admin user:** `<your-username>`

The Pi is reachable on the local network as `singularity-kiosk-wifi.local` via mDNS.

---

### 1. Operating System & Initial Prep

Flash **Raspberry Pi OS Lite (64-bit)** using Raspberry Pi Imager with these settings:

| Setting | Value |
|---|---|
| Username | `<your-username>` (local admin) |
| Hostname | `singularity-kiosk-wifi` |
| SSH | Enabled (Services tab) |
| WLAN Country | CH (Switzerland) |

> Do not set a password in the Imager — configure SSH key authentication instead (see step 5).

---

### 2. Software Installation & Cleanup

Connect via SSH and install the minimal graphical stack:

```bash
sudo apt update
sudo apt install --no-install-recommends xserver-xorg x11-xserver-utils xinit openbox chromium unclutter xserver-xorg-legacy -y
```

Purge the Raspberry Pi Connect cloud daemon to recover ~16MB RAM:

```bash
sudo apt remove rpi-connect-lite rpi-connect -y
```

---

### 3. raspi-config Configuration

```bash
sudo raspi-config
```

| Menu | Setting |
|---|---|
| System Options (S5) → Boot / Auto Login | **Console Autologin** |
| Localisation Options (L4) → WLAN Country | **CH** (Switzerland) |
| Interface Options (I2) → SSH | **Enabled** |
| Advanced Options (A6) → Wayland/X11 | **X11** (required for Openbox) |

Select **Finish** and reboot if prompted.

---

### 4. X Server Permissions

Allow the graphics layer to launch without desktop environment overhead:

```bash
sudo dpkg-reconfigure x11-common
# → Select "Anybody" from the menu
```

Verify the wrapper config:

```bash
sudo nano /etc/X11/Xwrapper.config
```

Ensure these two lines are at the bottom:

```
allowed_users=anybody
needs_root_rights=yes
```

---

### 5. Kiosk Startup Script

📄 **Script:** [`hardware/scripts/kiosk.sh`](scripts/kiosk.sh)

Copy to the Pi home directory and make it executable:

```bash
scp hardware/scripts/kiosk.sh <your-username>@singularity-kiosk-wifi.local:~/kiosk.sh
ssh <your-username>@singularity-kiosk-wifi.local "chmod +x ~/kiosk.sh"
```

**What the script does:**

- Sets `DISPLAY=:0` and creates tmpfs cache dirs
- Disables screen blanking and DPMS (screen stays on permanently)
- Cleans Chromium cache on each launch — clears Cache, Code Cache, Service Worker, Storage/ext, GPUCache — while preserving session cookies so HA login is remembered
- Infinite loop: relaunches Chromium automatically if killed by the memory watchdog
- Uses the raw `/usr/lib/chromium/chromium` binary directly — bypasses OS wrapper flags including the accessibility tree tracker
- `--single-process` + `--js-flags=--max-old-space-size=256` — keeps memory footprint low on the 2GB Pi 4
- `--disable-gpu` — avoids GPU driver issues on Pi headless stack

---

### 6. Autostart Configuration

**Openbox autostart:**

```bash
mkdir -p ~/.config/openbox
nano ~/.config/openbox/autostart
```

Add:

```bash
bash ~/kiosk.sh &
```

**`.bash_profile`** — launches X on TTY1 login, safe for SSH:

```bash
nano ~/.bash_profile
```

```bash
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
  exec startx
fi
```

> The `[ "$XDG_VTNR" = "1" ]` check ensures X only starts on the physical console — SSH sessions are unaffected.

---

### 7. Memory Watchdog & Cron

Chromium leaks memory over long sessions. The watchdog recycles it before the Pi runs out.

**Create the watchdog script:**

```bash
nano ~/memory_watchdog.sh
```

```bash
#!/bin/bash
# Minimum available memory in MB before restarting Chromium
THRESHOLD=80

AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$CURRENT_TIME] Current available memory: ${AVAILABLE_MEM}MB (Threshold: ${THRESHOLD}MB)"

if [ "$AVAILABLE_MEM" -lt "$THRESHOLD" ]; then
    echo "[$CURRENT_TIME] Memory is low! Recycling Chromium to free up space..."
    pkill -o chromium
fi
```

```bash
chmod +x ~/memory_watchdog.sh
```

**Add the cron job:**

```bash
crontab -e
```

Append at the bottom:

```
35 5,8,11,14,17,20 * * * /home/<your-username>/memory_watchdog.sh >> /home/<your-username>/memory_log.txt 2>&1
```

Runs at **:35** past each of these hours: 05:35, 08:35, 11:35, 14:35, 17:35, 20:35. Log output goes to `~/memory_log.txt`.

**Check the log anytime:**

```bash
tail -f ~/memory_log.txt
```

---

### 8. Swap File (2GB Safety Net)

```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Make it permanent:

```bash
sudo nano /etc/fstab
```

Add at the bottom:

```
/swapfile none swap sw 0 0
```

---

### 9. Home Assistant — Auto-Login (Trusted Network)

To bypass the HA login screen for the kiosk Pi, add the trusted networks auth provider to `/config/configuration.yaml` on the Home Assistant Pi and restart HA.

The kiosk logs into HA as the **`pisingularity`** Home Assistant user account. The trusted network config allows that login to happen automatically without a password prompt when the request comes from the kiosk Pi's IP.

```yaml
homeassistant:
  auth_providers:
    - type: trusted_networks
      trusted_networks:
        - 192.168.168.151/32  # Kiosk Pi static IP
      allow_bypass_login: true
    - type: homeassistant
```

> Assign the kiosk Pi a **static IP** (192.168.168.151) in your router's DHCP reservations to match this config. The `homeassistant` provider is kept as fallback for all other logins.

---

## SD Card Management

The kiosk image is cloned from the working setup. To backup or restore:

**Backup SD card to image (macOS):**
```bash
diskutil list                          # find device, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=/dev/rdisk4 of=~/Desktop/kiosk_backup.img bs=4m status=progress
```

**Restore image to SD card:**
```bash
diskutil list                          # find target device
diskutil unmountDisk /dev/disk4
sudo dd if=~/Desktop/kiosk_backup.img of=/dev/rdisk4 bs=4m status=progress
diskutil eject /dev/disk4
```

**Clone directly card-to-card** (requires USB card reader for second card):
```bash
sudo dd if=/dev/rdisk4 of=/dev/rdisk5 bs=4m status=progress
```

**GUI option:** [Apple Pi Baker](https://www.tweaking4all.com/hardware/raspberry-pi/applepi-baker-v2/) — free Mac app, backup and restore with a single button.

### After cloning — checklist

| Item | Command |
|---|---|
| Change hostname | `sudo hostnamectl set-hostname singularity-kiosk-wifi` |
| Regenerate SSH keys | `sudo rm /etc/ssh/ssh_host_* && sudo dpkg-reconfigure openssh-server` |
| Verify display resolution | Check `/boot/firmware/config.txt` for HDMI timings |
| Verify touch USB device | Confirm touch works after boot |
| First boot | Run `sudo raspi-config` → Advanced → Expand Filesystem |

---

## Power Summary

| Component | Supply |
|---|---|
| Joy-IT RB-LCD10-2 | 12V DC (dedicated) |
| Raspberry Pi 4 | 5V USB-C (official Pi 4 PSU recommended — 3A) |

> Keep the 12V display supply separate from the Pi 5V supply. Do not power the display from the Pi's USB ports.
