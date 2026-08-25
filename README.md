# singularity

> **Disclaimer:** I am not a professional developer, nor am I claiming to be.
> I have a good amount of hands-on coding experience with microcontrollers,
> Home Assistant, and automation systems. This project reflects that background —
> practical, functional, and built to solve a real problem.

---

## What is singularity?

singularity is an ESP32-S3 based brewing controller that integrates with
Home Assistant. It monitors temperatures across the brewing process using
NTC thermistors (via an ADS1115 ADC) and a DS18B20 digital sensor on a
1-Wire bus. Configuration is managed as code, version-controlled in Git,
and automatically deployed to Home Assistant via GitHub Actions over a
Tailscale VPN tunnel.

---

## Hardware

| Component | Role |
|---|---|
| ESP32-S3-DevKitC-1 | Main controller |
| ADS1115 (I2C, 0x48) | 16-bit ADC for NTC thermistors |
| NTC Thermistor × 2 | RIMS outlet temp (A0), Mash tun temp (A1) |
| DS18B20 | Digital 1-Wire temperature sensor |
| Raspberry Pi | Runs Home Assistant OS (HAOS) |

### Wiring Summary

| Signal | GPIO | Notes |
|---|---|---|
| I2C SDA | GPIO 21 | ADS1115 data |
| I2C SCL | GPIO 47 | ADS1115 clock |
| 1-Wire DQ | GPIO 48 | DS18B20 — 4.7 kΩ pull-up to 3.3 V required |

See `gpio_map.md` for the full pin rules and reserved GPIO list.

---

## Repository Structure

```
singularity/
├── esp32_singularity.yaml      # ESPHome firmware configuration
├── dashboard.yaml              # Home Assistant Lovelace dashboard
├── gpio_map.md                 # ESP32-S3 GPIO map and secrets reference
├── .gitignore                  # Excludes secrets.yaml and build artifacts
└── .github/
    └── workflows/
        └── deploy.yml          # CI/CD — auto-deploys to HA on push to main
```

---

## How Deployment Works

Every push to the `main` branch triggers the GitHub Actions workflow:

```
Push to main
     │
     ▼
GitHub Runner (ubuntu-latest)
     │
     │  tailscale/github-action@v2
     │  joins tailnet using TS_AUTHKEY (ephemeral)
     │
     ▼
Tailscale tunnel to Pi (100.66.190.74)
     │
     │  rsync over SSH (HA_SSH_KEY)
     │  installs rsync on Pi first (HAOS Alpine doesn't persist packages)
     │
     ▼
/config/esphome/ on Raspberry Pi
     │
     ▼
ESPHome picks up updated config → compile → OTA flash to ESP32-S3
```

The GitHub runner joins the tailnet as an ephemeral device and is
automatically removed when the job completes. It never appears permanently
in your Tailscale admin panel.

---

## Secrets

### On the Raspberry Pi — `/config/secrets.yaml` (never committed)

```yaml
# Wi-Fi — dirac_iot network (existing devices)
wifi_ssid: "dirac_iot"
wifi_password: "<your-password>"

# singularity — ESP32-S3 brewing controller
singularity_wifi_ssid: "tesla2"
singularity_wifi_password: "<your-password>"
singularity_ap_password: "<your-password>"
singularity_api_encryption_key: "<32-byte-base64-key>"
singularity_ota_password: "<your-password>"
```

All singularity secrets use the `singularity_` prefix to avoid collision
with other ESPHome devices on the `dirac_iot` network.

### On GitHub — Settings → Secrets → Actions

| Secret | Purpose |
|---|---|
| `HA_SSH_KEY` | RSA private key for `root@homeassistant` via Tailscale |
| `TS_AUTHKEY` | Tailscale ephemeral auth key — lets GitHub runner join tailnet |

Non-sensitive connection parameters are hardcoded in `deploy.yml`:
- Tailscale IP: `100.66.190.74`
- SSH port: `22`
- SSH user: `root`
- Config path: `/config/esphome`

---

## Setup Instructions

### Prerequisites

- Home Assistant OS running on a Raspberry Pi
- ESPHome add-on installed in HA
- Tailscale add-on installed and connected in HA
- GitHub repository at `https://github.com/exoticatom/singularity`

### Step 1 — Clone the repository

```bash
git clone https://github.com/exoticatom/singularity.git
cd singularity
```

### Step 2 — Configure secrets on the Pi

SSH into the Pi and add the singularity entries to `/config/secrets.yaml`.
Never commit this file — it is protected by `.gitignore`.

### Step 3 — Add GitHub Secrets

Go to `https://github.com/exoticatom/singularity/settings/secrets/actions`
and add:

- `HA_SSH_KEY` — contents of your SSH private key (`~/.ssh/id_rsa`)
- `TS_AUTHKEY` — generated at `https://login.tailscale.com/admin/settings/keys`
  - Type: Auth key
  - Reusable: yes
  - Ephemeral: yes

### Step 4 — First flash (USB)

The first flash must be done over USB since OTA requires the device to
already be running ESPHome firmware:

```bash
# Install ESPHome CLI if not already installed
pip install esphome

# Flash via USB (adjust port as needed)
esphome run esp32_singularity.yaml
```

After the first flash, all subsequent updates are pushed automatically
via OTA whenever you push to `main`.

### Step 5 — Get DS18B20 ROM address

After first boot, open the ESPHome logs in HA → ESPHome → singularity → Logs.
Look for a line like:

```
Found 1-Wire device: 0x28FF123456789ABC
```

Update `esp32_singularity.yaml` with the real address:

```yaml
- platform: dallas_temp
  address: 0x28FF123456789ABC   # ← replace placeholder
```

Push to `main` — the workflow deploys the update and ESPHome flashes OTA.

### Step 6 — Add the dashboard to Home Assistant

Open HA → Settings → Dashboards → Add Dashboard → select raw YAML editor
and paste the contents of `dashboard.yaml`.

---

## Open Items

| # | Item | Status |
|---|---|---|
| 1 | DS18B20 ROM address | Pending — requires hardware connected |
| 2 | NTC calibration (Beta, R values) | Using typical 10 kΩ / B=3950 defaults — verify against datasheet |
| 3 | Dashboard auto-load from config | Manual paste for now — automation planned |
| 4 | Brewing - Sofware notes integration | Notes file not yet provided |

---

## Change Log

| Date | Change |
|---|---|
| 2026-08-25 | Initial setup: GPIO map, ESPHome config, dashboard, CI/CD pipeline |
| 2026-08-25 | Secrets aligned to `singularity_` prefix convention |
| 2026-08-25 | CI/CD fixed: Tailscale integration, rsync on HAOS Alpine |
| 2026-08-25 | CI/CD verified: all steps green, files deploying to Pi |
