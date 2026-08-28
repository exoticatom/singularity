# singularity — Vitamin B Brewing Controller

[![GPIO Map](https://img.shields.io/badge/📌%20GPIO%20Map-View-blue)](hardware/gpio_map.md)
[![Hardware Docs](https://img.shields.io/badge/🔧%20Hardware%20Docs-View-blue)](hardware/README.md)
[![ESPHome Config](https://img.shields.io/badge/⚡%20ESPHome-v1.0.2-green)](esp32_singularity.yaml)
[![Dashboard](https://img.shields.io/badge/📊%20Dashboard-v1.0.3-orange)](singularity_dashboard.yaml)

> Built for **Vitamin B** — award-winning Belgian-style homebrews since 2012. 🍺

---

## About the Author

A/V enthusiast, vintage electronics restorer, FPGA tinkerer, home automation obsessive, mountain biker, and brewer. Several Swiss competition wins, mostly for Belgian styles. Brewing since 2012 (started way too late).

Restores Amigas and ZX Spectrums. Automates everything. Brews the rest.

> Just a heads-up: I'm not a pro dev. I just have a lot of hands-on experience tinkering with microcontrollers and Home Assistant. This project reflects that — it's practical, functional, and gets the job done.

---

## What is singularity?

singularity is an ESP32-S3 based brewing controller integrated with Home Assistant. It monitors temperatures across the brewing process, controls heating elements via SSR relays, and is designed to be extended with flow meters, proportional valves and automated brewing logic via Node-RED.

Configuration is managed as code, version-controlled in Git, and automatically deployed to Home Assistant via GitHub Actions over a Tailscale VPN tunnel.

### Architecture

The system is split into three distinct layers, each with a clear responsibility:

```
┌─────────────────────────────────────────────────────────┐
│                     Node-RED                            │
│  Process automation — mash schedules, PID, sequences    │
│  Reads sensors from HA, sends commands to ESP32         │
└────────────────────────┬────────────────────────────────┘
                         │ reads entities / calls services
┌────────────────────────▼────────────────────────────────┐
│                  Home Assistant                         │
│  Dashboard — display, settings, calibration, logs       │
│  DS18B20 offset helpers — adjustable without reflash    │
│  Templates — DS18B20 corrected values                   │
└────────────────────────┬────────────────────────────────┘
                         │ ESPHome native API
┌────────────────────────▼────────────────────────────────┐
│                    ESP32-S3                             │
│  Reads NTC voltage, runs S-H calc, publishes °C         │
│  Reads DS18B20 digital temp, publishes °C               │
│  NTC calibration params stored on flash (persist reboot)│
│  Controls SSR relays on command                         │
└─────────────────────────────────────────────────────────┘
```

**ESP32** runs the NTC Steinhart-Hart calculation locally using parameters stored in flash. Even if HA is unavailable the controller continues with last known calibration values.

**Home Assistant** handles DS18B20 offset correction, display and logging. NTC calibration is written to ESP32 via `number` entities which persist to flash.

**Node-RED** (planned) implements brewing sequences and PID control at the highest level.

---

## Hardware

📖 Full hardware documentation → **[hardware/](hardware/README.md)**

| Category | Components |
|---|---|
| **Controller** | ESP32-S3-DEV-KIT-NXRX + expansion adapter board |
| **Temperature** | NTC 10kΩ thermistors × 2 (via ADS1115 ADC), DS18B20 1-Wire sensors × 2 |
| **Flow** | IFM SM6004 magnetic flow meters (planned), YF-S200 pulse sensors (planned) |
| **Analog I/O** | ADS1115 16-bit ADC × 1 (0x48 — NTC1 A0, NTC2 A1, FLOW1 A2, FLOW2 A3), MCP4728 12-bit DAC × 2 (planned) |
| **GPIO expansion** | MCP23017 16-bit I2C expander (planned) |
| **Outputs** | SSR relays × 2 (RIMS heater + spare) |
| **Signal conversion** | 4-20mA → 0-3.3V converter modules for industrial sensors |
| **Infrastructure** | Raspberry Pi running Home Assistant OS (HAOS) |

### Pinout Reference

→ [hardware/gpio_map.md](hardware/gpio_map.md)

---

## Repository Structure

```
singularity/
├── esp32_singularity.yaml        # ESPHome firmware configuration
├── singularity_dashboard.yaml    # Home Assistant Lovelace dashboard (auto-deployed)
├── assets/                       # Hardware reference images and datasheets
├── hardware/                     # Hardware documentation
│   ├── README.md                 # Hardware index
│   ├── esp32.md                  # ESP32-S3 board overview and pinout
│   ├── esp32_expansion_board.md  # Expansion adapter board
│   ├── gpio_map.md               # GPIO pin rules and bus assignments
│   ├── ntc.md                    # NTC thermistor wiring and S-H calibration
│   ├── ds18b20.md                # DS18B20 wiring and ROM address discovery
│   ├── expansion_boards.md       # I2C boards (ADS1115, MCP4728, MCP23017)
│   ├── current_to_voltage.md     # 4-20mA → 0-3.3V converter module
│   ├── sm6004.md                 # IFM SM6004 magnetic flow sensor
│   └── yf_s200.md                # YF-S200 pulse flow sensor
├── .gitignore
└── .github/workflows/deploy.yml  # CI/CD — auto-deploys to HA on push to main
```

---

## Design Philosophy

**ESP32 — the controller (firmware only; reflash required for sensor/filter changes):**
- Reads hardware at fixed 1s interval, applies EMA filter (α=0.25)
- Runs full Steinhart-Hart calculation for NTC sensors on-device
- All calibration parameters (NTC S-H coefficients, DS18B20 offsets) stored on ESP32 flash
- Parameters persist across reboots — controller works without HA after first setup
- **After any restart mid-brew: ESP32 restores all parameters from flash and resumes immediately**
- Publishes corrected °C values directly to HA
- SSR states restored from flash on reboot (`RESTORE_DEFAULT_OFF` → last known state)
- Executes SSR on/off when instructed by HA or Node-RED

**PID control — runs on ESP32, configured from HA:**
- PID runs entirely on the ESP32, not in HA templates or Node-RED
- Setpoint, Kp, Ki, Kd and max duty cycle are `number` entities — adjustable from the Settings tab without reflash
- All PID parameters persist to flash — a power loss mid-brew resumes with the same tuning
- RIMS heater uses `slow_pwm` output (period: 2s) — required for SSR compatibility; SSRs cannot switch at kHz frequencies
- Max duty cycle is a safety cap — limits heater output even at full PID demand
- Rationale: PID on ESP32 means the controller keeps regulating temperature even if HA goes offline

**Home Assistant — display and configuration only (no calculations):**
- All calibration and PID parameters → Settings tab (writes to ESP32 `number` entities, saved to flash)
- HA is a configuration UI, not a control layer — if HA restarts, the brew continues unaffected
- Logging → logbook tab; reconnect automation re-pushes all 14 calibration values to ESP32 on reconnect
- Last known firmware version stays visible on dashboard even when ESP32 is offline

**Process automation — planned: Node-RED**
Complex brewing sequences (mash schedules, step mashing, automated valve control) planned via Node-RED as a HA add-on. PID tuning and setpoint scheduling will be orchestrated from Node-RED, writing to the ESP32 `number` entities.

**Rule:** Calculations and state that must survive a reboot live on the ESP32. Configuration and display live in HA. Sequences and scheduling live in Node-RED.

---

## Dashboard

Five tabs, auto-deployed on every push to `main`:

| Tab | Description |
|---|---|
| **Brewing Temperatures** | Online/offline banner, corrected sensor readings, SSR controls, history graph |
| **Log** | ESP32 connectivity events, SSR activity graph (24h) |
| **Settings** | NTC S-H calibration on ESP32 (R, V-ref, A, B, C, Offset), DS18B20 offsets |
| **About** | System versions (ESP32 firmware, dashboard, HA templates) |
| **Hardware** | ESP32 pinout, pin assignment table, I2C device map |

---

## How Deployment Works

Every push to `main` triggers the GitHub Actions workflow automatically:

```
Push to main
     │
     ▼
GitHub Runner (ubuntu-latest)
     │  joins tailnet via TS_AUTHKEY (ephemeral)
     ▼
Tailscale tunnel → Raspberry Pi
     │  rsync over SSH
     ├── /config/esphome/     ← ESPHome YAML configs
     └── /config/             ← singularity_dashboard.yaml
```

Can also be triggered manually: `https://github.com/exoticatom/singularity/actions` → Run workflow

### Secrets *(developer only)*

> This section is only relevant for maintaining the CI/CD pipeline.

**On the Raspberry Pi — `/config/secrets.yaml`** (never committed, gitignored)

```yaml
wifi_ssid: "<your-main-ssid>"
wifi_password: "<your-password>"
singularity_wifi_ssid: "<your-singularity-ssid>"
singularity_wifi_password: "<your-password>"
singularity_ap_password: "<your-password>"
singularity_api_encryption_key: "<32-byte-base64-key>"
singularity_ota_password: "<your-password>"
```

**On GitHub — Settings → Secrets → Actions:**

| Secret | Purpose |
|---|---|
| `HA_SSH_KEY` | RSA private key for SSH to Pi via Tailscale |
| `TS_AUTHKEY` | Tailscale ephemeral auth key (reusable, ephemeral) |

---

## Setup Instructions

### Prerequisites

- Raspberry Pi running Home Assistant OS
- ESPHome add-on installed in HA
- Tailscale add-on installed and connected in HA
- HACS installed + **mini-graph-card** by kalkih

### Step 1 — Clone the repository

```bash
git clone https://github.com/exoticatom/singularity.git
cd singularity
```

### Step 2 — Create local secrets.yaml

```yaml
singularity_wifi_ssid: "<your-ssid>"
singularity_wifi_password: "<your-password>"
singularity_ap_password: "<your-password>"
singularity_api_encryption_key: "<your-key>"
singularity_ota_password: "<your-password>"
```

### Step 3 — Add GitHub Secrets *(developer only)*

> Only needed for CI/CD. Skip if running firmware locally.

- `HA_SSH_KEY` — `~/.ssh/id_rsa` contents
- `TS_AUTHKEY` — from `https://login.tailscale.com/admin/settings/keys` (Reusable + Ephemeral)

### Step 4 — Add lovelace entry to Pi

Append to `/config/configuration.yaml`:

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

### Step 5 — First flash (USB)

**Option A — Local CLI** *(currently used)*
```bash
brew install pipx && pipx install esphome && pipx ensurepath
esphome run esp32_singularity.yaml
```

**Option B — Web Flasher** *(to be reviewed for production)*
[web.esphome.io](https://web.esphome.io) in Chrome — no tooling needed.

**Option C — OTA** *(after first flash only)*
All subsequent updates deploy automatically via OTA on every push to `main`.

### Step 6 — DS18B20 ROM addresses *(already done for this installation)*

Addresses are hardcoded in `esp32_singularity.yaml`:
- `DS18B20-Boil`: `0x750000105cbe3528`
- `DS18B20-HLT`: `0x3100000c31dd5a28`

For new sensors see [hardware/ds18b20.md](hardware/ds18b20.md) for discovery options.

---

## Planned Expansions

> 📖 See **[hardware/ →](hardware/README.md)** for full hardware documentation including wiring, calibration and datasheets.

| Item | Status |
|---|---|
| ADS1115 A2 + SM6004 flow meters × 2 | Planned — A2/A3 on existing board (0x48) |
| MCP4728 × 2 — DAC for proportional valve | Planned |
| MCP23017 — GPIO expander | Planned |
| YF-S200 pulse flow sensors | Planned |
| Node-RED — process automation (PID, mash schedules, step sequences) | Future |

---

## Change Log

| Date | Change |
|---|---|
| 2026-08-25 | Initial setup: ESPHome config, dashboard, CI/CD pipeline |
| 2026-08-25 | CI/CD: Tailscale + rsync to HAOS — all steps green |
| 2026-08-26 | Steinhart-Hart NTC calibration configurable from dashboard |
| 2026-08-26 | Hardware documentation folder with 9 pages |
| 2026-08-26 | PID number entities on ESP32 (setpoint, Kp, Ki, Kd, duty cycle), slow_pwm RIMS heater, reconnect automation, DS18B20 wiring schematic |

---

<div align="center">
  <img src="assets/Vitamin-Bv.0.1.png" alt="Vitamin B" width="200"/>
</div>
