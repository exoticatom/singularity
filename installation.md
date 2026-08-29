# singularity — Installation Guide

> ← Back to **[README.md](README.md)**

Choose your path:

- **[👤 End User Setup](#-end-user-setup)** — flash the board, connect to HA, done
- **[🛠️ Developer Setup](#️-developer-setup)** — everything above + CI/CD auto-deploy pipeline

---

## 👤 End User Setup

Everything you need to get singularity running on your hardware.

### Prerequisites

- Raspberry Pi running [Home Assistant](home_assistant.md) OS (HAOS)
- ESPHome add-on installed in HA
- [ESP32-S3-DevKitC-1](hardware/esp32.md) board
- USB-C cable for first flash

### Step 1 — Flash the firmware (USB, first time only)

Use the ESPHome web flasher — no tooling needed:

1. Open [web.esphome.io](https://web.esphome.io) in Chrome
2. Connect [ESP32](hardware/esp32.md) via USB-C
3. Click **Connect** → select the serial port
4. Click **Install** and select `esp32_singularity.yaml`

> After the first flash all future updates happen automatically over WiFi (OTA).

### Step 2 — Create secrets file on the Pi

SSH into your Pi or use the HA file editor. Create `/config/secrets.yaml` (if it doesn't exist) and add:

```yaml
singularity_wifi_ssid: "<your-ssid>"
singularity_wifi_password: "<your-wifi-password>"
singularity_ap_password: "<fallback-ap-password>"
singularity_api_encryption_key: "<32-byte-base64-key>"
singularity_ota_password: "<ota-password>"
```

> To generate an API encryption key: in ESPHome dashboard → **Secrets** → generate, or use `openssl rand -base64 32`.

### Step 3 — Add dashboard to HA

Append to `/config/configuration.yaml` on the Pi:

```yaml
lovelace:
  dashboards:
    singularity-brewing:
      mode: yaml
      title: singularity
      icon: mdi:thermometer
      show_in_sidebar: true
      filename: singularity_dashboard.yaml

template: !include_dir_merge_list singularity_templates/

recorder:
  exclude:
    entities:
      - sensor.singularity_uptime      # 1s heartbeat — not useful as history
      - sensor.singularity_wifi_signal # 60s diagnostic — not useful as history
```

### Step 4 — Copy dashboard and template files to Pi

Copy these files from the repo to `/config/` on the Pi:
- `singularity_dashboard.yaml`
- `singularity_templates/singularity_templates.yaml`

### Step 5 — Restart HA

Settings → System → Restart. The singularity dashboard will appear in the sidebar.

### Step 6 — DS18B20 ROM addresses

If you are using the **same physical sensors** as this installation, nothing to do — addresses are already hardcoded:
- `DS18B20-Boil`: `0x750000105cbe3528`
- `DS18B20-HLT`: `0x3100000c31dd5a28`

If you have **different sensors**, discover the addresses and update `esp32_singularity.yaml`. See [hardware/ds18b20.md](hardware/ds18b20.md) for discovery options.

### Step 7 — Calibrate sensors

Open the singularity dashboard → **Settings tab** and enter calibration values for your sensors. See [hardware/calibration.md](hardware/calibration.md) for full procedures.

---

## 🛠️ Developer Setup

Everything in End User Setup, plus the CI/CD pipeline for automatic deploys on every `git push`.

### Additional Prerequisites

- Git + GitHub account with a fork of this repo
- Tailscale account (for the VPN tunnel from GitHub Actions to the Pi)
- Tailscale add-on installed and connected in HA
- ESPHome CLI installed locally (`pipx install esphome`)

### Step 1 — Clone the repo

```bash
git clone https://github.com/exoticatom/singularity.git
cd singularity
```

### Step 2 — Create local secrets.yaml

Same as end user Step 2 — create `secrets.yaml` in the repo root (gitignored).

### Step 3 — First flash via CLI

```bash
esphome run esp32_singularity.yaml
```

### Step 4 — Set up GitHub Secrets for CI/CD

In your GitHub repo → Settings → Secrets → Actions, add:

| Secret | Value |
|---|---|
| `HA_SSH_KEY` | Contents of `~/.ssh/id_rsa` (SSH key with access to the Pi) |
| `TS_AUTHKEY` | Tailscale ephemeral auth key — from [tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys) (Reusable + Ephemeral) |

### Step 5 — Push to deploy

Every push to `main` automatically:
1. Connects to the Pi via Tailscale VPN
2. Copies `singularity_dashboard.yaml` and `singularity_templates/` to `/config/`
3. Copies `esp32_singularity.yaml` to `/config/esphome/`
4. OTA flash is triggered by ESPHome on the Pi

See `.github/workflows/deploy.yml` for the full pipeline.
