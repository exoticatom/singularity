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
| ESP32-S3-DEV-KIT-NXRX | Main controller (ESP32-S3-WROOM module) |
| ADS1115 #1 (I2C, 0x48) | 16-bit ADC — NTC thermistors |
| NTC Thermistor × 2 | RIMS outlet temp (A0), Mash tun temp (A1) |
| DS18B20 | Digital 1-Wire temperature sensor |
| Raspberry Pi | Runs Home Assistant OS (HAOS) |

### Pinout Reference

![ESP32-S3-DEV-KIT-NXRX pinout](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-S3-Devkit-n16r8.jpg)

![ESP32-S3-DEV-KIT-NXRX board](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-S3-Devkit-n16r8_2.jpg)

### Wiring Summary

| Signal | GPIO | Notes |
|---|---|---|
| I2C SDA | GPIO 21 | ADS1115 data |
| I2C SCL | GPIO 47 | ADS1115 clock |
| 1-Wire DQ | GPIO 48 | DS18B20 — 4.7 kΩ pull-up to 3.3 V required |

See `gpio_map.md` for the full pin rules, reserved GPIO list, and secrets reference.

---

## Repository Structure

```
singularity/
├── esp32_singularity.yaml        # ESPHome firmware configuration
├── singularity_dashboard.yaml    # Home Assistant Lovelace dashboard (auto-deployed)
├── gpio_map.md                   # ESP32-S3 GPIO map, bus assignments, secrets reference
├── assets/                       # Hardware reference images
│   ├── ESP32-S3-Devkit-n16r8.jpg
│   └── ESP32-S3-Devkit-n16r8_2.jpg
├── .gitignore                    # Excludes secrets.yaml and build artifacts
└── .github/
    └── workflows/
        └── deploy.yml            # CI/CD — auto-deploys to HA on push to main
```

---

## Dashboard

The singularity dashboard has two tabs:

**Brewing Temperatures** — live sensor readings (NTC1-RIMS, NTC2-MASH, DS18B20-Kettle)

**Hardware** — ESP32-S3 pinout diagrams, pin assignment table, I2C device map

The dashboard is automatically deployed to the Pi on every push to `main` and
loaded by HA via the `lovelace.dashboards.singularity-brewing` entry in
`/config/configuration.yaml`. No manual pasting required.

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
     ├── /config/esphome/     ← ESPHome YAML configs
     └── /config/             ← singularity_dashboard.yaml
          │
          ▼
ESPHome picks up updated config → compile → OTA flash to ESP32-S3
HA Lovelace reloads dashboard automatically
```

The workflow can also be triggered manually from:
`https://github.com/exoticatom/singularity/actions` → Run workflow button

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
- Tailscale IP: `100.66.190.74` — SSH port: `22` — user: `root`
- ESPHome config path: `/config/esphome` — dashboard path: `/config/`

---

## Setup Instructions

### Prerequisites

- Home Assistant OS running on a Raspberry Pi
- ESPHome add-on installed in HA
- Tailscale add-on installed and connected in HA (`100.66.190.74`)
- GitHub repository at `https://github.com/exoticatom/singularity`
- HACS installed in HA — [installation guide](https://hacs.xyz/docs/use/)
- HACS custom card: **mini-graph-card** by kalkih
  - HACS → Frontend → search "mini-graph-card" → Download

### Step 1 — Clone the repository

```bash
git clone https://github.com/exoticatom/singularity.git
cd singularity
```

### Step 2 — Create local secrets.yaml (for ESPHome CLI)

Create `secrets.yaml` in the project folder (already gitignored):

```yaml
singularity_wifi_ssid: "tesla2"
singularity_wifi_password: "<your-password>"
singularity_ap_password: "<your-password>"
singularity_api_encryption_key: "<your-key>"
singularity_ota_password: "<your-password>"
```

### Step 3 — Add GitHub Secrets

Go to `https://github.com/exoticatom/singularity/settings/secrets/actions` and add:

- `HA_SSH_KEY` — contents of your SSH private key (`~/.ssh/id_rsa`)
- `TS_AUTHKEY` — generated at `https://login.tailscale.com/admin/settings/keys`
  - Type: Auth key — Reusable: yes — Ephemeral: yes

### Step 4 — Add lovelace entry to configuration.yaml on Pi

SSH into the Pi and append to `/config/configuration.yaml`:

```yaml
lovelace:
  dashboards:
    singularity-brewing:
      mode: yaml
      title: singularity
      icon: mdi:thermometer
      show_in_sidebar: true
      filename: singularity_dashboard.yaml
```

Then reload HA configuration (Developer Tools → YAML → Reload all).

### Step 5 — First flash (USB, one time only)

```bash
# Install ESPHome via pipx
brew install pipx
pipx install esphome
pipx ensurepath

# Flash via USB
esphome run esp32_singularity.yaml
```

After the first flash all subsequent updates deploy automatically via OTA on every push to `main`.

### Step 6 — Get DS18B20 ROM address

After first boot open HA → ESPHome → singularity → Logs and look for:

```
Found 1-Wire device: 0x28FF123456789ABC
```

Update `esp32_singularity.yaml` with the real address and push to `main`.

---

## Planned Expansions

| Item | Status |
|---|---|
| ADS1115 #2 (0x49) — SM6004 flow meters × 2 | Planned |
| MCP4728 #1 (0x60) — DAC proportional valve control | Planned |
| MCP4728 #2 (0x61) — DAC expansion outputs | Planned |
| Dynamic port assignment via HA helpers + templates | Future |

---

## Open Items

| # | Item | Status |
|---|---|---|
| 1 | DS18B20 ROM address | Pending — hardware not yet arrived |
| 2 | NTC calibration (Beta, R values) | Using 10 kΩ / B=3950 defaults — verify against datasheet |
| 3 | Brewing - Sofware notes integration | Notes file not yet provided |

---

## Change Log

| Date | Change |
|---|---|
| 2026-08-25 | Initial setup: GPIO map, ESPHome config, dashboard, CI/CD pipeline |
| 2026-08-25 | Secrets aligned to `singularity_` prefix convention |
| 2026-08-25 | CI/CD: Tailscale integration, rsync on HAOS Alpine — all steps green |
| 2026-08-25 | Dashboard: auto-deploy to `/config/`, lovelace entry in configuration.yaml |
| 2026-08-25 | Hardware tab added to dashboard with pinout images from GitHub |
| 2026-08-25 | Repo made public to enable raw image URLs in Lovelace dashboard |
