# singularity — Vitamin B Brewing Controller

[![GPIO Map](https://img.shields.io/badge/📌%20GPIO%20Map-View-blue)](hardware/gpio_map.md)
[![Hardware Docs](https://img.shields.io/badge/🔧%20Hardware%20Docs-View-blue)](hardware/README.md)
[![ESPHome Config](https://img.shields.io/badge/⚡%20ESPHome-v1.1.1-green)](esp32_singularity.yaml)
[![Dashboard](https://img.shields.io/badge/📊%20Dashboard-v1.3.5-orange)](singularity_dashboard.yaml)
[![Project Status](https://img.shields.io/badge/📋%20Project%20Status-View-brightgreen)](#project-status)
[![Calibration Guide](https://img.shields.io/badge/🧪%20Calibration-Guide-blueviolet)](hardware/calibration.md)
[![Home Assistant](https://img.shields.io/badge/🏠%20Home%20Assistant-Integration-teal)](home_assistant.md)
[![Installation](https://img.shields.io/badge/📦%20Installation-Guide-blue)](installation.md)

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
| **Controller** | [Waveshare ESP32-S3-WROOM-1 N16R8 44-Pin](hardware/esp32.md) (Board 2, active) + [expansion adapter board](hardware/esp32_expansion_board.md) |
| **Temperature** | [NTC](hardware/ntc.md) 10kΩ thermistors × 2 (via [ADS1115](hardware/expansion_boards.md) ADC), [DS18B20](hardware/ds18b20.md) 1-Wire sensors × 2 |
| **Flow** | IFM [SM6004](hardware/sm6004.md) magnetic flow meters × 2 (🔬 Testing), [YF-S200](hardware/yf_s200.md) pulse sensors (planned) |
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
├── installation.md                   # Installation guide — end user and developer
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

## Installation

→ **[installation.md](installation.md)** — End User and Developer setup guides

---

## How Deployment Works

> *Developer only — skip if you are not maintaining the CI/CD pipeline.*

Every push to `main` automatically deploys to the Pi via GitHub Actions + Tailscale:

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
     └── /config/             ← singularity_dashboard.yaml + singularity_templates/
```

Can also be triggered manually: `https://github.com/exoticatom/singularity/actions` → Run workflow

**Required GitHub Secrets** (Settings → Secrets → Actions):

| Secret | Purpose |
|---|---|
| `HA_SSH_KEY` | RSA private key for SSH to Pi via Tailscale |
| `TS_AUTHKEY` | Tailscale ephemeral auth key (reusable, ephemeral) |

See [installation.md](installation.md#️-developer-setup) for full setup steps.

---

## Project Status

### Hardware

| Component | Status | Notes |
|---|---|---|
| [ESP32-S3-DevKitC-1](hardware/esp32.md) | ✅ Active | Firmware v1.1.1 — running on Board 2 (44-pin N16R8, 25.4mm wide) |
| [ADS1115](hardware/expansion_boards.md) #1 (0x48) | ✅ Active | Both channels confirmed on I2C scan |
| [NTC1-RIMS thermistor](hardware/ntc.md) | ✅ Tested | Reading correctly on A0 |
| [NTC2-MASH thermistor](hardware/ntc.md) | ✅ Tested | Reading correctly on A1 |
| [ADS1115](hardware/expansion_boards.md) #2 (0x49) | 🔬 On hold | Floating input issue — see note below |
| [DS18B20](hardware/ds18b20.md)-Boil | ✅ Tested | ROM `0x750000105cbe3528` confirmed |
| [DS18B20](hardware/ds18b20.md)-HLT | ✅ Tested | ROM `0x3100000c31dd5a28` confirmed |
| SSR1 (GPIO41) | ⏳ Wired | Not load tested |
| SSR2 — RIMS heater (GPIO42) | ⏳ Wired | PID ready, not load tested |
| [SM6004](hardware/sm6004.md) flow meters × 2 | 🔬 Testing | Connected, calibrated — AN1 (A2 RIMS) + AN2 (A3 Sparge). Firmware implemented v1.0.9. |
| Relay board — pump control | 🔲 Planned | Via [MCP23017](hardware/expansion_boards.md) GPIO expander |
| [MCP23017](hardware/expansion_boards.md) GPIO expander | 🔲 Planned | I2C 0x20 |
| [MCP4728](hardware/expansion_boards.md) DAC | 🔲 Planned | Proportional valve, I2C 0x60 |
| Alarm/buzzer | 🔲 Planned | Hardware + HA notification |

> **Note — ADS1115 #2 floating input issue:** Two boards were tested. One drifted **negative** (below GND) — ESPHome correctly returns `unavailable`. The other drifted **positive** (~0.58V) — produced false temperature readings (~64°C) with nothing connected. A PID relying on a false 64°C reading could behave dangerously. Root cause not confirmed — may be board-specific. 6 more boards ordered for testing. **Decision: all 4 channels (A0–A3) stay on ADS1115 #1 (0x48). ADS1115 #2 is not in scope** — flow meters will also use #1 A2/A3.

### Software

| Feature | Status | Notes |
|---|---|---|
| ESPHome firmware v1.1.1 | ✅ Active | OTA updates working |
| NTC Steinhart-Hart calc on ESP32 | ✅ Tested | Both NTCs reading correctly |
| DS18B20 offset correction on ESP32 | ✅ Tested | Both sensors confirmed |
| Flash persistence (restore_value) | ✅ Tested | Survives reboot |
| PID RIMS heater control | ✅ Implemented | Kp=10 Ki=0.2 Kd=5 — not load tested |
| 90°C runaway safety guard | ✅ Implemented | Heater off if NTC > 90°C |
| CI/CD auto-deploy via GitHub Actions | ✅ Active | Push to main → Pi via Tailscale |
| HA dashboard v1.3.5 | ✅ Active | 5 tabs, mushroom sensor cards, apexcharts graph, AN1/AN2 flow cards |
| Uptime heartbeat (1s) | ✅ Active | Fast 10s offline detection via template |
| Reconnect automation | ✅ Active | Re-pushes calibration on ESP32 reconnect |
| Flow meter firmware (SM6004) | ✅ Implemented | AN1 (RIMS, A2) + AN2 (Sparge, A3) — rate + total + offset + reset |
| Pump relay control | 🔲 Planned | MCP23017 |
| Proportional valve control | 🔲 Planned | MCP4728 DAC |
| Node-RED mash schedules + timers | 🔲 Planned | Mash step automation, alarms |

---

## Planned Expansions

> 📖 See **[hardware/ →](hardware/README.md)** for full hardware documentation including wiring, calibration and datasheets.

| Item | Status |
|---|---|
| [ADS1115](hardware/expansion_boards.md) A2/A3 + [SM6004](hardware/sm6004.md) flow meters × 2 | 🔬 Testing — calibrated, firmware implemented |
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
| 2026-08-26 | Steinhart-Hart NTC calibration on ESP32 — all params configurable from dashboard |
| 2026-08-26 | Hardware documentation folder — 11 pages covering all components |
| 2026-08-26 | PID RIMS heater control — slow_pwm, Kp/Ki/Kd/duty from dashboard, flash-persisted |
| 2026-08-26 | DS18B20 offset correction on ESP32 — persisted to flash |
| 2026-08-26 | Reconnect automation — re-pushes 14 calibration values on ESP32 reconnect |
| 2026-08-26 | Dashboard v1.1.x — offline banners, default values in Settings, calibration cards |
| 2026-08-26 | Fast connectivity detection — 10s offline via uptime heartbeat template |
| 2026-08-26 | Firmware v1.0.8 — 1s uptime heartbeat, 3min reboot_timeout |
| 2026-08-26 | Recorder exclude — uptime + wifi_signal removed from HA DB |
| 2026-08-26 | Documentation: home_assistant.md, calibration.md, installation.md added |
| 2026-08-26 | Dashboard v1.2.0 — apexcharts-card temperature graph (4 sensors + live setpoint line) |
| 2026-08-26 | Dashboard v1.2.1–v1.2.3 — mushroom-template-card sensor grid with per-sensor colour thresholds |
| 2026-08-26 | SM6004 flow meters connected + calibrated — max 13.20 L/min, slope 7.57 L/V, ESPHome config pending |
| 2026-09-02 | Firmware v1.0.9 — AN1 (RIMS flow A2) + AN2 (Sparge flow A3): rate, total, offset, reset buttons |
| 2026-09-02 | Dashboard v1.3.x — AN1/AN2 flow cards, reset buttons, Board 2 hardware tab |

---

<div align="center">
  <img src="assets/Vitamin-Bv.0.1.png" alt="Vitamin B" width="200"/>
</div>
