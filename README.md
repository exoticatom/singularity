# singularity

[![GPIO Map](https://img.shields.io/badge/📌%20GPIO%20Map-View-blue)](hardware/gpio_map.md)
[![Hardware Docs](https://img.shields.io/badge/🔧%20Hardware%20Docs-View-blue)](hardware/README.md)
[![ESPHome Config](https://img.shields.io/badge/⚡%20ESPHome-v1.9.1-green)](esp32_singularity.yaml)
[![Dashboard](https://img.shields.io/badge/📊%20Dashboard-v1.5.2-orange)](singularity_dashboard.yaml)

> Just a heads-up: I'm not a pro dev. I just have a lot of hands-on experience tinkering with microcontrollers and Home Assistant. This project reflects that—it's practical, functional, and gets the job done.

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
| DS18B20-Boil | 1-Wire — Boil kettle (ROM: `0x750000105cbe3528`) |
| DS18B20-HLT | 1-Wire — Hot Liquor Tank (ROM: `0x3100000c31dd5a28`) |
| SSR Relay × 2 | SSR1 (GPIO 41), SSR2 (GPIO 42) — ALWAYS_OFF on boot |
| Raspberry Pi | Runs Home Assistant OS (HAOS) |

> DS18B20 ROM addresses are unique to this hardware installation.

### Pinout Reference

See [hardware/esp32.md](hardware/esp32.md) for board overview, pinout diagrams and full wiring summary.

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
├── assets/                       # Hardware reference images
├── hardware/                     # Hardware documentation
│   ├── README.md                 # Hardware index page
│   ├── gpio_map.md               # ESP32-S3 GPIO pin rules and bus assignments
│   ├── ntc.md                    # NTC thermistor wiring and S-H calibration
│   ├── ds18b20.md                # DS18B20 wiring and ROM address discovery
│   ├── expansion_boards.md       # I2C boards, pull-up rules, address map
│   ├── sm6004.md                 # SM6004 magnetic flow sensor
│   └── yf_s200.md                # YF-S200 pulse flow sensor
├── .gitignore                    # Excludes secrets.yaml and build artifacts
└── .github/
    └── workflows/
        └── deploy.yml            # CI/CD — auto-deploys to HA on push to main
```

---

## Design Philosophy

singularity follows a strict separation between firmware and configuration:

**ESP32 — firmware only (reflash required for changes):**
- Reads hardware at fixed 1s interval
- Applies EMA filter (α=0.25) to reduce electrical noise
- Publishes `_RAW` sensor values to HA
- Executes output commands (SSR on/off) when instructed by HA
- No calibration values, no thresholds, no control logic

**Home Assistant — all configurable from dashboard (no reflash):**
- Calibration offsets → `input_number` helpers in Settings tab
- Corrected display values → template sensors (`singularity_templates/`)
- Setpoints and thresholds → `input_number` helpers (future)
- Control logic → automations and templates (future)
- Logging → logbook tab

**Process automation — planned: Node-RED**
Complex brewing process automation (mash schedules, PID control, step sequences) is planned via Node-RED, which can be installed directly as a Home Assistant add-on. Node-RED sits between HA and the ESP32 — reading sensor entities and controlling SSR outputs without reflashing firmware.

**Rule:** If a value can change without touching hardware, it belongs in HA or Node-RED, not ESP32.
Reflash only when hardware changes (new sensor, new GPIO, new bus).

**Data flow:**
```
ESP32 hardware
    │  reads every 1s, EMA filter
    ▼
sensor.*_raw          ← raw, uncalibrated HA entities
    │
    + input_number.singularity_offset_*   ← set in Settings tab
    │
    ▼
sensor.*              ← corrected entities used for display and automation
```

---

The singularity dashboard has four tabs:

**Brewing Temperatures** — live corrected sensor readings, SSR controls, brewing graph

**Log** — SSR on/off activity log (24h) with purge button

**Settings** — per-sensor calibration offset controls, RAW vs Corrected comparison

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
Tailscale tunnel to Pi (your-tailscale-ip)
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
# Wi-Fi — main network (existing devices)
wifi_ssid: "<your-main-ssid>"
wifi_password: "<your-password>"

# singularity — ESP32-S3 brewing controller
singularity_wifi_ssid: "<your-singularity-ssid>"
singularity_wifi_password: "<your-password>"
singularity_ap_password: "<your-password>"
singularity_api_encryption_key: "<32-byte-base64-key>"
singularity_ota_password: "<your-password>"
```

All singularity secrets use the `singularity_` prefix to avoid collision
with other ESPHome devices on your main network.

### On GitHub — Settings → Secrets → Actions

| Secret | Purpose |
|---|---|
| `HA_SSH_KEY` | RSA private key for `root@homeassistant` via Tailscale |
| `TS_AUTHKEY` | Tailscale ephemeral auth key — lets GitHub runner join tailnet |

Non-sensitive connection parameters are hardcoded in `deploy.yml`:
- Tailscale IP: `<your-tailscale-ip>` — SSH port: `22` — user: `root`
- ESPHome config path: `/config/esphome` — dashboard path: `/config/`

---

## Setup Instructions

### Prerequisites

- Home Assistant OS running on a Raspberry Pi
- ESPHome add-on installed in HA
- Tailscale add-on installed and connected in HA
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
singularity_wifi_ssid: "<your-singularity-ssid>"
singularity_wifi_password: "<your-password>"
singularity_ap_password: "<your-password>"
singularity_api_encryption_key: "<your-key>"
singularity_ota_password: "<your-password>"
```

### Step 3 — Add GitHub Secrets *(developer only)*

> This step is only needed to maintain the CI/CD deployment pipeline.
> Skip if you are just running the firmware locally.

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

### Step 5 — First flash (USB)

The first flash must be done over USB since OTA requires the device to already be running ESPHome firmware. Three options:

**Option A — Local CLI** *(currently used)*
```bash
brew install pipx
pipx install esphome
pipx ensurepath
esphome run esp32_singularity.yaml
```

**Option B — ESPHome Web Flasher** *(to be reviewed once solution is in production)*
Connect ESP32 via USB and open [web.esphome.io](https://web.esphome.io) in Chrome. No local tooling needed.

**Option C — OTA** *(after first flash only)*
All subsequent updates deploy automatically via OTA on every push to `main`. No USB needed.

### Step 6 — DS18B20 ROM addresses (already done for this installation)

**Design decision:** ROM addresses are hardcoded in `esp32_singularity.yaml` rather than using auto-discovery. This ensures each sensor is permanently mapped to its physical location regardless of boot order.

**Current addresses (this installation):**
- `DS18B20-Boil`: `0x750000105cbe3528`
- `DS18B20-HLT`: `0x3100000c31dd5a28`

**If you add a new DS18B20 or replace one — how to get the ROM address:**

This is a manual step. The address is unique per physical sensor and must be discovered before it can be used.

**Option A — ESPHome logs with DEBUG (recommended, used in this project)**
1. Set `logger: level: DEBUG` in `esp32_singularity.yaml`
2. Flash and connect the ESP32
3. Open **HA → ESPHome → singularity → Logs**
4. Look for: `Found 1-Wire device: 0x28XXXXXXXXXXXXXX`
5. Copy the address, add it to the config, set logger back to INFO

**Option B — Remove the address field temporarily**
Remove `address:` from the sensor config entirely. ESPHome will scan and report all found devices in the logs on boot, then warn "Please add the address to your configuration."

**Option C — ESPHome CLI scan**
```bash
esphome run esp32_singularity.yaml
```
Watch the serial output on first boot — the ROM address appears in the first few seconds.

**Option D — Arduino sketch**
Flash a simple 1-Wire scanner sketch via Arduino IDE. It prints all found device addresses to the serial monitor. Useful if you have multiple sensors and want to identify them before wiring into the main board.

> Note: DEBUG logging generates a lot of output. Remember to switch back to INFO once the address is captured.

---

## Planned Expansions

| Item | Status |
|---|---|
| ADS1115 #2 (0x49) — SM6004 flow meters × 2 | Planned |
| MCP4728 #1 (0x60) — DAC proportional valve control | Planned |
| MCP4728 #2 (0x61) — DAC expansion outputs | Planned |
| MCP23017 — GPIO expander for relay outputs | Planned |
| YF-S200 pulse flow sensors | Planned |
| Dynamic port assignment via HA helpers + templates | Future |
| SSR automation logic (RIMS PID) | Future |

See [hardware/expansion_boards.md](hardware/expansion_boards.md) for I2C address map and board details.

---

## Change Log

| Date | Change |
|---|---|
| 2026-08-25 | Initial setup: GPIO map, ESPHome config, dashboard, CI/CD pipeline |
| 2026-08-25 | Secrets aligned to `singularity_` prefix convention |
| 2026-08-25 | CI/CD: Tailscale integration, rsync on HAOS Alpine — all steps green |
| 2026-08-25 | Dashboard: auto-deploy to `/config/`, lovelace entry in configuration.yaml |
| 2026-08-26 | Steinhart-Hart NTC calibration configurable from dashboard |
| 2026-08-26 | Hardware documentation folder created |
