# singularity — Vitamin B Brewing Controller

[![GPIO Map](https://img.shields.io/badge/📌%20GPIO%20Map-View-blue)](hardware/gpio_map.md)
[![Hardware Docs](https://img.shields.io/badge/🔧%20Hardware%20Docs-View-blue)](hardware/README.md)
[![ESPHome Config](https://img.shields.io/badge/⚡%20ESPHome-v1.0.8-green)](esp32_singularity.yaml)
[![Dashboard](https://img.shields.io/badge/📊%20Dashboard-v1.1.9-orange)](singularity_dashboard.yaml)
[![Project Status](https://img.shields.io/badge/📋%20Project%20Status-View-brightgreen)](#project-status)
[![Calibration Guide](https://img.shields.io/badge/🧪%20Calibration-Guide-blueviolet)](hardware/calibration.md)
[![Home Assistant](https://img.shields.io/badge/🏠%20Home%20Assistant-Integration-teal)](home_assistant.md)

> Built for **Vitamin B** — award-winning Belgian-style homebrews since 2012. 🍺

---

## About the Author

A/V enthusiast, vintage electronics restorer, FPGA tinkerer, home automation obsessive, mountain biker, and brewer. Several Swiss competition wins, mostly for Belgian styles. Brewing since 2012 (started way too late).

Restores Amigas and ZX Spectrums. Automates everything. Brews the rest.

> Just a heads-up: I'm not a pro dev. I just have a lot of hands-on experience tinkering with microcontrollers and Home Assistant. This project reflects that — it's practical, functional, and gets the job done.

---

## What is singularity?

singularity is an [ESP32-S3](hardware/esp32.md) based brewing controller integrated with [Home Assistant](home_assistant.md). It monitors temperatures across the brewing process, controls heating elements via SSR relays, and is designed to be extended with flow meters, proportional valves and automated brewing logic via Node-RED.

Configuration is managed as code, version-controlled in Git, and automatically deployed to [Home Assistant](home_assistant.md) via GitHub Actions over a Tailscale VPN tunnel.

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
│  DS18B20 offset correction via ESP32 number entities    │
│  Fast connectivity template (10s offline detection)     │
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

**[Home Assistant](home_assistant.md)** is display and configuration only. [DS18B20](hardware/ds18b20.md) offsets are written to [ESP32](hardware/esp32.md) `number` entities (stored on flash). [NTC](hardware/ntc.md) calibration parameters are also on flash. HA shows live readings, logs events, and provides a settings UI — the ESP32 runs the brew independently.

**Node-RED** (planned) implements brewing sequences and PID control at the highest level.

---

## Hardware

📖 Full hardware documentation → **[hardware/](hardware/README.md)**

| Category | Components |
|---|---|
| **Controller** | [ESP32-S3-DEV-KIT-NXRX](hardware/esp32.md) + [expansion adapter board](hardware/esp32_expansion_board.md) |
| **Temperature** | [NTC](hardware/ntc.md) 10kΩ thermistors × 2 (via [ADS1115](hardware/expansion_boards.md) ADC), [DS18B20](hardware/ds18b20.md) 1-Wire sensors × 2 |
| **Flow** | IFM [SM6004](hardware/sm6004.md) magnetic flow meters (planned), [YF-S200](hardware/yf_s200.md) pulse sensors (planned) |
| **Analog I/O** | [ADS1115](hardware/expansion_boards.md) 16-bit ADC × 1 (0x48 — NTC1 A0, NTC2 A1, FLOW1 A2, FLOW2 A3), [MCP4728](hardware/expansion_boards.md) 12-bit DAC × 2 (planned) |
| **GPIO expansion** | [MCP23017](hardware/expansion_boards.md) 16-bit I2C expander (planned) |
| **Outputs** | SSR relays × 2 (RIMS heater + spare) |
| **Signal conversion** | [4-20mA → 0-3.3V converter modules](hardware/current_to_voltage.md) for industrial sensors |
| **Infrastructure** | Raspberry Pi running [Home Assistant](home_assistant.md) OS (HAOS) |

### Pinout Reference

→ [hardware/gpio_map.md](hardware/gpio_map.md)

---

## Repository Structure

```
singularity/
├── home_assistant.md                 # Home Assistant integration — entities, dashboard, automations
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
│   ├── yf_s200.md                # YF-S200 pulse flow sensor
│   └── calibration.md            # Calibration guide — NTC, DS18B20, ADS1115, SM6004, PID
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

**[Home Assistant](home_assistant.md) — display and configuration only (no calculations):**
- All calibration and PID parameters → Settings tab (writes to ESP32 `number` entities, saved to flash)
- HA is a configuration UI, not a control layer — if HA restarts, the brew continues unaffected
- Logging → logbook tab; reconnect automation re-pushes all 14 calibration values to ESP32 on reconnect
- Last known firmware version stays visible on dashboard even when ESP32 is offline

**Process automation — planned: Node-RED**
Complex brewing sequences (mash schedules, step mashing, automated valve control) planned via Node-RED as a HA add-on. PID tuning and setpoint scheduling will be orchestrated from Node-RED, writing to the ESP32 `number` entities.

**Rule:** Calculations and state that must survive a reboot live on the ESP32. Configuration and display live in HA. Sequences and scheduling live in Node-RED.

**Rule — incremental complexity:** Start with the simplest working implementation. Do not cover edge cases upfront. Add complexity only when a real need is confirmed. Simple code is easier to debug on a microcontroller with limited tooling.

---

## Dashboard

Five tabs, auto-deployed on every push to `main`:

| Tab | Description |
|---|---|
| **Brewing Temperatures** | Online/offline banner, corrected sensor readings, SSR controls, history graph |
| **Log** | ESP32 connectivity events, SSR activity graph (24h) |
| **Settings** | NTC S-H calibration on ESP32 (R, V-ref, A, B, C, Offset), DS18B20 offsets |
| **About** | System versions (ESP32 firmware, dashboard) |
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

---

### 👤 End User Setup

Everything you need to get singularity running on your hardware.

#### Prerequisites

- Raspberry Pi running [Home Assistant](home_assistant.md) OS (HAOS)
- ESPHome add-on installed in HA
- ESP32-S3-DevKitC-1 board
- USB-C cable for first flash

#### Step 1 — Flash the firmware (USB, first time only)

Use the ESPHome web flasher — no tooling needed:

1. Open [web.esphome.io](https://web.esphome.io) in Chrome
2. Connect ESP32 via USB-C
3. Click **Connect** → select the serial port
4. Click **Install** and select `esp32_singularity.yaml`

> After the first flash all future updates happen automatically over WiFi (OTA).

#### Step 2 — Create secrets file on the Pi

SSH into your Pi or use the HA file editor. Create `/config/secrets.yaml` (if it doesn't exist) and add:

```yaml
singularity_wifi_ssid: "<your-ssid>"
singularity_wifi_password: "<your-wifi-password>"
singularity_ap_password: "<fallback-ap-password>"
singularity_api_encryption_key: "<32-byte-base64-key>"
singularity_ota_password: "<ota-password>"
```

> To generate an API encryption key: in ESPHome dashboard → **Secrets** → generate, or use `openssl rand -base64 32`.

#### Step 3 — Add dashboard to HA

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
      - sensor.singularity_uptime
      - sensor.singularity_wifi_signal
```

#### Step 4 — Copy dashboard and template files to Pi

Copy these files from the repo to `/config/` on the Pi:
- `singularity_dashboard.yaml`
- `singularity_templates/singularity_templates.yaml`

#### Step 5 — Restart HA

Settings → System → Restart. The singularity dashboard will appear in the sidebar.

#### Step 6 — DS18B20 ROM addresses

If you are using different DS18B20 sensors than this installation, you need to discover and update the ROM addresses in `esp32_singularity.yaml`. See [hardware/ds18b20.md](hardware/ds18b20.md) for discovery options.

The addresses for **this installation** are already hardcoded:
- `DS18B20-Boil`: `0x750000105cbe3528`
- `DS18B20-HLT`: `0x3100000c31dd5a28`

#### Step 7 — Calibrate sensors

Open the singularity dashboard → **Settings tab** and enter calibration values for your sensors. See [hardware/calibration.md](hardware/calibration.md) for procedures.

---

### 🛠️ Developer Setup

Everything above, plus the CI/CD pipeline for automatic deploys on every `git push`.

#### Additional Prerequisites

- Git + GitHub account with a fork of this repo
- Tailscale account (for the VPN tunnel from GitHub Actions to the Pi)
- Tailscale add-on installed and connected in HA
- ESPHome CLI installed locally (`pipx install esphome`)

#### Step 1 — Clone the repo

```bash
git clone https://github.com/exoticatom/singularity.git
cd singularity
```

#### Step 2 — Create local secrets.yaml

Same as end user Step 2 — create `secrets.yaml` in the repo root (it is gitignored).

#### Step 3 — First flash via CLI

```bash
esphome run esp32_singularity.yaml
```

#### Step 4 — Set up GitHub Secrets for CI/CD

In your GitHub repo → Settings → Secrets → Actions, add:

| Secret | Value |
|---|---|
| `HA_SSH_KEY` | Contents of `~/.ssh/id_rsa` (SSH key with access to the Pi) |
| `TS_AUTHKEY` | Tailscale ephemeral auth key — from [tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys) (Reusable + Ephemeral) |

#### Step 5 — Push to deploy

Every push to `main` automatically:
1. Connects to the Pi via Tailscale VPN
2. Copies `singularity_dashboard.yaml` and `singularity_templates/` to `/config/`
3. Copies `esp32_singularity.yaml` to `/config/esphome/`
4. OTA flash is triggered by ESPHome on the Pi

See `.github/workflows/deploy.yml` for the full pipeline.

---

## Project Status

### Hardware

| Component | Status | Notes |
|---|---|---|
| [ESP32-S3-DevKitC-1](hardware/esp32.md) | ✅ Active | Firmware v1.0.8 |
| [ADS1115](hardware/expansion_boards.md) #1 (0x48) | ✅ Active | Both channels confirmed on I2C scan |
| [NTC1-RIMS thermistor](hardware/ntc.md) | ✅ Tested | Reading correctly on A0 |
| [NTC2-MASH thermistor](hardware/ntc.md) | ✅ Tested | Reading correctly on A1 |
| [ADS1115](hardware/expansion_boards.md) #2 (0x49) | 🔬 On hold | Floating input issue — see note below |
| [DS18B20](hardware/ds18b20.md)-Boil | ✅ Tested | ROM `0x750000105cbe3528` confirmed |
| [DS18B20](hardware/ds18b20.md)-HLT | ✅ Tested | ROM `0x3100000c31dd5a28` confirmed |
| SSR1 (GPIO41) | ⏳ Wired | Not load tested |
| SSR2 — RIMS heater (GPIO42) | ⏳ Wired | PID ready, not load tested |
| [SM6004](hardware/sm6004.md) flow meters × 2 | 🔲 Planned | ADS1115 A2/A3 + [4-20mA converters](hardware/current_to_voltage.md) |
| Relay board — pump control | 🔲 Planned | Via [MCP23017](hardware/expansion_boards.md) GPIO expander |
| [MCP23017](hardware/expansion_boards.md) GPIO expander | 🔲 Planned | I2C 0x20 |
| [MCP4728](hardware/expansion_boards.md) DAC | 🔲 Planned | Proportional valve, I2C 0x60 |
| Alarm/buzzer | 🔲 Planned | Hardware + HA notification |

> **Note — ADS1115 #2 floating input issue:** Two boards were tested. One drifted **negative** (below GND) — ESPHome correctly returns `unavailable`. The other drifted **positive** (~0.58V) — produced false temperature readings (~64°C) with nothing connected. A PID relying on a false 64°C reading could behave dangerously. Root cause not confirmed — may be board-specific. 6 more boards ordered for testing. **Decision: all 4 channels (A0–A3) stay on ADS1115 #1 (0x48). ADS1115 #2 is not in scope** — flow meters will also use #1 A2/A3.

### Software

| Feature | Status | Notes |
|---|---|---|
| ESPHome firmware v1.0.8 | ✅ Active | OTA updates working |
| NTC Steinhart-Hart calc on ESP32 | ✅ Tested | Both NTCs reading correctly |
| DS18B20 offset correction on ESP32 | ✅ Tested | Both sensors confirmed |
| Flash persistence (restore_value) | ✅ Tested | Survives reboot |
| PID RIMS heater control | ✅ Implemented | Kp=10 Ki=0.2 Kd=5 — not load tested |
| 90°C runaway safety guard | ✅ Implemented | Heater off if NTC > 90°C |
| CI/CD auto-deploy via GitHub Actions | ✅ Active | Push to main → Pi via Tailscale |
| HA dashboard v1.1.9 | ✅ Active | 5 tabs, touch-friendly |
| Uptime heartbeat (1s) | ✅ Active | Fast 10s offline detection via template |
| Reconnect automation | ✅ Active | Re-pushes calibration on ESP32 reconnect |
| Flow meter firmware (SM6004) | 🔲 Planned | ADS1115 A2/A3 |
| Pump relay control | 🔲 Planned | MCP23017 |
| Proportional valve control | 🔲 Planned | MCP4728 DAC |
| Node-RED mash schedules + timers | 🔲 Planned | Mash step automation, alarms |

---

## Planned Expansions

> 📖 See **[hardware/ →](hardware/README.md)** for full hardware documentation including wiring, calibration and datasheets.

| Item | Status |
|---|---|
| [ADS1115](hardware/expansion_boards.md) A2 + [SM6004](hardware/sm6004.md) flow meters × 2 | Planned — A2/A3 on existing board (0x48) |
| [MCP4728](hardware/expansion_boards.md) × 2 — DAC for proportional valve | Planned |
| [MCP23017](hardware/expansion_boards.md) — GPIO expander | Planned |
| [YF-S200](hardware/yf_s200.md) pulse flow sensors | Planned |
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
