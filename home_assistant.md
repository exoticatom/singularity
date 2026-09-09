# singularity — Home Assistant Integration

> ← Back to **[README.md](README.md)**

This page documents everything configured in [Home Assistant](https://www.home-assistant.io) for the singularity brewing controller — entities, automations, templates, dashboard, and how they all connect.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Home Assistant                             │
│                                                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │  Dashboard   │  │ Automations  │  │  Template Sensors      │ │
│  │ (Lovelace)  │  │ (reconnect)  │  │  (fast connectivity)   │ │
│  └──────┬──────┘  └──────┬───────┘  └───────────┬────────────┘ │
│         │                │                       │              │
│         └────────────────┼───────────────────────┘              │
│                          │                                      │
│                   ESPHome Native API (encrypted)                │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                ┌──────────▼──────────┐
                │     ESP32-S3        │
                │  singularity v1.1.9 │
                └─────────────────────┘
```

---

## Entity Map

All singularity entities in [Home Assistant](https://www.home-assistant.io) — what they do and where they come from.

### Sensors (read-only, from ESP32)

```
sensor.singularity_ntc1_rims          °C     NTC1 on ADS1115 A0 — RIMS tube temp (S-H calc on ESP32)
sensor.singularity_ntc2_mash          °C     NTC2 on ADS1115 A1 — Mash tun temp (S-H calc on ESP32)
sensor.singularity_ds18b20_boil       °C     DS18B20 on 1-Wire GPIO48 (offset applied on ESP32)
sensor.singularity_ds18b20_hlt        °C     DS18B20 on 1-Wire GPIO48 (offset applied on ESP32)
sensor.singularity_an1_raw_voltage    V      ADS1115 A2 raw voltage — RIMS flow diagnostic
sensor.singularity_an1_rate           L/min  RIMS flow rate (SM6004 #1 via XY-IT0V, ADS1115 A2)
sensor.singularity_an1_total          L      RIMS flow session total (resets on reboot or button)
sensor.singularity_an2_raw_voltage    V      ADS1115 A3 raw voltage — Sparge flow diagnostic
sensor.singularity_an2_rate           L/min  Sparge flow rate (SM6004 #2 via XY-IT0V, ADS1115 A3)
sensor.singularity_an2_total          L      Sparge flow session total (resets on reboot or button)
sensor.singularity_build              str    Firmware version string (e.g. "v1.1.4") — updates every 10s
sensor.singularity_safety_event       str    Last RIMS safety event — published by ESP32, stored in HA logbook (offline-persistent)
sensor.singularity_uptime             s      Seconds since last boot — updates every 1s (heartbeat)
sensor.singularity_wifi_signal        dBm    WiFi RSSI — updates every 60s (diagnostic)
```

### Binary Sensors

```
binary_sensor.singularity_esp32_status       on/off  Native ESPHome connectivity (slow — ~30-60s)
binary_sensor.singularity_esp32_fast_status  on/off  Template sensor — offline within 10s (see below)
```

### Number Entities (read/write, persisted on ESP32 flash)

```
NTC1-RIMS Calibration:
  number.singularity_ntc1_r_fixed       Ω     Fixed resistor value (default: 9883)
  number.singularity_ntc1_v_ref         V     Reference voltage (default: 3.3)
  number.singularity_ntc1_sh_a                S-H coefficient A (default: 1.207e-3)
  number.singularity_ntc1_sh_b                S-H coefficient B (default: 2.183e-4)
  number.singularity_ntc1_sh_c                S-H coefficient C (default: 1.764e-7)
  number.singularity_ntc1_offset        °C    Single-point offset (default: 0.0)

NTC2-MASH Calibration:
  number.singularity_ntc2_r_fixed       Ω     Fixed resistor value (default: 9902)
  number.singularity_ntc2_v_ref         V     Reference voltage (default: 3.3)
  number.singularity_ntc2_sh_a                S-H coefficient A (default: 1.210e-3)
  number.singularity_ntc2_sh_b                S-H coefficient B (default: 2.173e-4)
  number.singularity_ntc2_sh_c                S-H coefficient C (default: 1.848e-7)
  number.singularity_ntc2_offset        °C    Single-point offset (default: 0.0)

DS18B20 Offsets:
  number.singularity_ds18b20_boil_offset  °C  Offset for Boil sensor (default: 0.0)
  number.singularity_ds18b20_hlt_offset   °C  Offset for HLT sensor (default: 0.0)

PID Control:
  number.singularity_pid_setpoint       °C    Target temperature (default: 66.0, range 0-80)
  number.singularity_pid_kp                   Proportional gain (default: 10.0)
  number.singularity_pid_ki                   Integral gain (default: 0.2)
  number.singularity_pid_kd                   Derivative gain (default: 5.0)
  number.singularity_pid_max_duty_cycle  %    Heater output cap (default: 100)
  number.singularity_pid_min_flow        L/min RIMS min-flow interlock threshold (default: 2.0) — only enforced when flow interlock enabled

Flow Calibration:
  number.singularity_an1_flow_offset    L/min  AN1 RIMS flow offset (default: 0.0)
  number.singularity_an2_flow_offset    L/min  AN2 Sparge flow offset (default: 0.0)
```

### Switches (read/write, persisted on ESP32 flash)

```
switch.singularity_rims_heater             ON/OFF   Enables PID control loop → SSR2 (GPIO42)
switch.singularity_ssr1                    ON/OFF   SSR1 direct control (GPIO41)
switch.singularity_flow_interlock_enable   ON/OFF   Arms RIMS dry-fire guard — heater refuses to fire below pid_min_flow. Default OFF (dormant until AN1 flow meter commissioned)
```

### Buttons

```
button.singularity_an1_reset_total   Press to zero AN1 running total (session reset)
button.singularity_an2_reset_total   Press to zero AN2 running total (session reset)
```

### Automation

```
automation.singularity_push_calibration_values_on_esp32_reconnect
  Trigger : binary_sensor.singularity_esp32_status → ON
  Delay   : 3 seconds (allow ESP32 to finish boot)
  Action  : Write all 14 calibration values back to ESP32 number entities
  Purpose : Ensures HA and ESP32 stay in sync after any reconnect
```

---

## Connectivity Detection

Two-layer connectivity detection:

```
Layer 1 — Native ESPHome (slow)
  binary_sensor.singularity_esp32_status
  Detection time: ~30-60s after disconnect
  Source: ESPHome native API keepalive

Layer 2 — Fast template (fast)
  binary_sensor.singularity_esp32_fast_status
  Detection time: ~10s after disconnect
  Source: monitors sensor.singularity_uptime (1s heartbeat)
  Logic: if uptime not updated for >10s → offline
```

```
ESP32 online  →  sensor.singularity_uptime updates every 1s
                          │
                          ▼
              Template checks last_updated timestamp
                          │
              ┌───────────┴───────────┐
           < 10s                   > 10s
              │                       │
           ON ✅                   OFF ❌
              │                       │
         🟢 Online              🔴⚠️ Offline
         banners clear          banners shown on all tabs
```

### Template sensor definition

Defined in `/config/singularity_templates/singularity_templates.yaml`:

```yaml
- binary_sensor:
    - name: "singularity ESP32 Fast Status"
      unique_id: singularity_esp32_fast_status
      device_class: connectivity
      state: >
        {{ states('sensor.singularity_uptime') not in ['unavailable','unknown','none']
           and (now() - states.sensor.singularity_uptime.last_updated).total_seconds() < 10 }}
      attributes:
        uptime_seconds: "{{ states('sensor.singularity_uptime') | float(0) | round(1) }}"
        wifi_signal: "{{ states('sensor.singularity_wifi_signal') | default('unknown') }} dBm"
        offline_seconds: "{{ (now() - states.sensor.singularity_uptime.last_updated).total_seconds() | int }}"
```

> **Entity ID Rule:** Always reference `binary_sensor.singularity_esp32_fast_status` in automations and dashboards — never the bare form. HA auto-generates entity IDs with the `singularity_` prefix; this prevents collision with other projects.

---

## Dashboard

**File:** `singularity_dashboard.yaml` → deployed to `/config/singularity_dashboard.yaml`
**Version:** v1.4.0
**Registered in:** `/config/configuration.yaml` as `lovelace` dashboard

### Tab layout

```
┌──────────────┬─────┬──────────┬───────┬──────────┬──────┐
│  🌡️ Brewing  │ 📋  │  ⚙️      │  ℹ️   │  🔌      │  📈  │
│    Temps     │ Log │ Settings │ About │ Hardware │ Diag │
└──────────────┴─────┴──────────┴───────┴──────────┴──────┘
```

### Tab 1 — Brewing Temperatures

```
┌────────────────────────────────────────────┐
│  🟢 singularity.local — Online             │  ← conditional banner
├──────────────────┬─────────────────────────┤
│ 🌡️ NTC1-RIMS     │ 🌡️ NTC2-MASH            │  mushroom cards, colour by temp
│ 🌡️ DS18B20-Boil  │ 🌡️ DS18B20-HLT          │
├──────────────────┬─────────────────────────┤
│  AN1 RIMS Flow   │  AN2 Sparge Flow        │  rate + total + reset button
├────────────────────────────────────────────┤
│  RIMS Heater [toggle]  Target Temp [slider]│
├────────────────────────────────────────────┤
│  📈 apexcharts — 4 sensors + setpoint line │
│     1h span, 5s refresh, 0-100°C           │
└────────────────────────────────────────────┘
```

### Tab 2 — Log

```
┌────────────────────────────────────────────┐
│  Activity Log (logbook 24h)                │
│   • Safety events (offline-persistent)     │
│   • UI actions: heater, mode, setpoint,    │
│     SSR1, flow interlock                   │
│   • Connectivity + firmware build          │
│  SSR / RIMS Activity (history-graph 24h)   │
│   • SSR1, RIMS Heater, RIMS Mode           │
└────────────────────────────────────────────┘
```

### Tab 3 — Settings

```
┌────────────────────────────────────────────┐
│  DS18B20 Offsets                           │
│  NTC1-RIMS Steinhart-Hart Calibration      │
│  NTC2-MASH Steinhart-Hart Calibration      │
│  RIMS Heater PID Control                   │
│  RIMS Flow Interlock — Safety              │
│  AN1 RIMS Flow Calibration (offset+reset)  │
│  AN2 Sparge Flow Calibration (offset+reset)│
│  How calibration works                     │
└────────────────────────────────────────────┘
```

### Tab 4 — About

```
┌────────────────────────────────────────────┐
│  System Versions (live firmware + dashboard│
│  version from ESP32 build sensor)          │
│  Sensor map, GPIO assignments table        │
└────────────────────────────────────────────┘
```

### Tab 5 — Hardware

```
┌────────────────────────────────────────────┐
│  Board 2 (active) + Board 1 (reference)    │
│  Pin Assignments table                     │
│  I2C Device Map table                      │
└────────────────────────────────────────────┘
```

### Tab 6 — Diag

```
┌────────────────────────────────────────────┐
│  AN1 RIMS Flow (ADS1115 A2)                │
│  • Raw Voltage  • Rate  • Total            │
│  • Offset  • Reset button                  │
│  📈 Raw voltage graph (5min)               │
│  📈 Flow rate graph (5min)                 │
├────────────────────────────────────────────┤
│  AN2 Sparge Flow (ADS1115 A3)              │
│  • Raw Voltage  • Rate  • Total            │
│  • Offset  • Reset button                  │
│  📈 Raw voltage graph (5min)               │
│  📈 Flow rate graph (5min)                 │
└────────────────────────────────────────────┘
```

---

## Logging & Activity Log

The Log tab is an **activity log**, not a sensor archive. It records discrete
events and user actions — never streamed sensor values (temperatures and flow
are already covered by the history graphs / recorder).

### Design principle — offline persistence

```
┌─ ESP32 serial log (ESP_LOGI / ESP_LOGW) ─────────────────────┐
│  Ephemeral. Lives only on the USB console / ESPHome viewer.   │
│  GONE the instant the ESP32 reboots, loses WiFi, or powers    │
│  down. Detailed numbers (PID cycle, stale ms, temp, flow).    │
└──────────────────────────────────────────────────────────────┘
┌─ HA recorder database (on the Pi) ───────────────────────────┐
│  Durable. Every logged item is a Home Assistant ENTITY state  │
│  change, stored on the Pi independently of the ESP32.         │
│  Survives an ESP32 reboot / power cut / WiFi outage.          │
│  Retention: HA recorder default (10 days).                    │
└──────────────────────────────────────────────────────────────┘
```

> **Rule:** anything that must be visible while the ESP32 is offline has to be a
> Home Assistant entity state change. Serial-only logs do not qualify.

### What is logged (all HA-side → offline-persistent)

| Category | Source entity | Notes |
|---|---|---|
| Safety events | `sensor.singularity_safety_event` | Stale / NAN / over-temp / low-flow trips, recovery, boot |
| RIMS heater on/off | `switch.singularity_rims_heater` | UI action |
| RIMS mode (PID/DC) | `select.singularity_rims_mode` | UI action |
| PID setpoint change | `number.singularity_pid_setpoint` | UI action |
| SSR1 on/off | `switch.singularity_ssr1` | UI action |
| Flow interlock arm | `switch.singularity_flow_interlock_enable` | UI action |
| Connectivity | `binary_sensor.singularity_esp32_fast_status` | Online/offline transitions |
| Firmware build | `sensor.singularity_build` | Version string |

### What is deliberately NOT logged

- Temperatures (NTC1/2, DS18B20) and flow rate/total — history graphs cover these.
- Per-cycle PID output (`temp / err / I / D / out`) — serial-only; far too noisy
  for a logbook (~43k rows/day).

### Safety event entity — `sensor.singularity_safety_event`

A firmware `text_sensor` (no lambda / no self-update) that the PID loop publishes
to when a guard trips. It bridges the serial-only `ESP_LOGW` safety warnings into
HA so trips remain in the logbook after the controller goes offline.

```
Guard (every 2s PID cycle)          Logbook message
─────────────────────────────────   ─────────────────────────────
sensor staleness (I2C wedged)    →   "Sensor stale — heater OFF"
sensor NAN / disconnect          →   "Sensor fault (NAN) — heater OFF"
over-temp > 90°C hard limit      →   "Over-temp >90°C — heater OFF"
flow interlock (low flow)        →   "Low flow — heater OFF"
all guards passed (recovery)     →   "OK — heating"
boot                             →   "Boot — controller started"
```

**Edge-guarded publishing:** each message is published only when it differs from
the current state (`if (id(safety_event).state != msg) …`). A persistent fault
logs **once**, not every 2 s cycle. Messages are intentionally static (no varying
numbers) so a condition cannot spam the logbook; the detailed numeric values
(stale ms, exact temp, exact flow) still go to the serial `ESP_LOGW` for live
debugging. A boot publish registers the entity in HA and marks each restart.

---


```
/config/
├── configuration.yaml              ← lovelace + template include + recorder exclude
├── automations.yaml                ← reconnect automation (line ~1530)
├── singularity_dashboard.yaml      ← deployed from git via CI/CD
└── singularity_templates/
    └── singularity_templates.yaml  ← fast connectivity template (deployed via CI/CD)
```

### configuration.yaml additions

```yaml
# Lovelace dashboard
lovelace:
  dashboards:
    singularity-brewing:
      mode: yaml
      title: singularity
      icon: mdi:thermometer
      show_in_sidebar: true
      filename: singularity_dashboard.yaml

# Fast connectivity template
template: !include_dir_merge_list singularity_templates/

# Recorder exclude — uptime is the 1s heartbeat for fast-status detection,
# but there is no value storing 86,400 rows/day in the DB.
recorder:
  exclude:
    entities:
      - sensor.singularity_uptime      # 1s heartbeat — not useful as history
      - sensor.singularity_wifi_signal # 60s diagnostic — not useful as history
```

---

## Reconnect Automation

When the ESP32 reconnects after any outage, HA automatically re-sends all 14 calibration values.

```
trigger: binary_sensor.singularity_esp32_status → ON
          │
          ▼ delay 3s (wait for full boot)
          │
          ▼ write all 14 number entities:
            NTC1: R-fixed, V-ref, A, B, C, Offset
            NTC2: R-fixed, V-ref, A, B, C, Offset
            DS18B20: Boil offset, HLT offset
```

> **Note — PID Flash Persistence:** PID parameters (Setpoint, Kp, Ki, Kd, Max Duty) and flow offsets are **not** re-pushed on reconnect because they persist independently on ESP32 flash. This is intentional — the ESP32 resumes a brew with the exact tuning from before the HA outage. Re-pushing would be redundant and could interrupt active PID control.

---

## Calibration Flow

```
HA Settings tab
      │
      │  User changes value (e.g. NTC1 R-Fixed)
      ▼
number.singularity_ntc1_r_fixed
      │
      │  ESPHome native API
      ▼
ESP32 on_value lambda
      │
      ├─→ ESP32 flash (NVS)  ← persists forever
      │
      └─→ NTC filter lambda uses new value immediately
                │
                ▼
      sensor.singularity_ntc1_rims updates within 1s
```

---

## Dynamic Sensor Mapping (Planned)

**Architecture Rule:** Do not hardcode sensor roles to physical pins in the firmware. Define generic ports (e.g., `adc_port_a0` on the ADS1115) and map them dynamically via Home Assistant `input_select` helpers.

**Why:** Swapping a failed sensor or repurposing a pin should not require firmware reflash. Instead, HA provides dropdown menus to reassign which physical channel feeds which calculated value.

**Example (future):**
```
input_select.singularity_ntc1_role
  Options: "RIMS Temperature", "Mash Temperature", "Disabled"
  Default: "RIMS Temperature"
  
input_select.singularity_ntc1_adc_channel
  Options: "ADS1115 #1 A0", "ADS1115 #1 A1", "ADS1115 #1 A2", "ADS1115 #1 A3"
  Default: "ADS1115 #1 A0"
```

HA publishes these selections to the ESP32 as `number` entities; the firmware applies them to configure the ADC read pipeline without reflash.

**Status:** Planned — implement when sensor replacement or reallocation becomes necessary.

---

## Orphaned Entities (safe to delete from HA)

These entities exist in the HA registry from old firmware versions and are no longer used.

### Cleanup Instructions

1. **One-time cleanup:** Go to **Settings → Devices & Services → Entities** and search for each entity below
2. **Delete:** Click each entity and select **Delete** — confirm the deletion
3. **Verify:** After deletion, refresh the page to confirm the entity is gone from the registry
4. **Automation check:** If an automation references a deleted entity, HA will show a warning; remove the automation or fix the reference

### Orphaned Entity List

| Entity | Reason |
|---|---|
| `input_number.singularity_ntc1_*` / `ntc2_*` | Replaced by `number.*` entities on ESP32 flash |
| `input_number.singularity_offset_*` | Replaced by `number.*` entities |
| `input_text.singularity_ssr1_name` / `ssr2_name` | Old UI helpers, never used |
| `number.singularity_rims_direct_duty_cycle` | Old DIRECT mode removed v1.0.5 |
| `number.singularity_rims_pid_switch_threshold` | Old DIRECT mode removed v1.0.5 |
| `switch.singularity_an1_reset_total` / `an2_reset_total` | Replaced by `button.*` entities |
| `switch.singularity_ssr2` / `ssr2_rims_heater` / `ssr1_spare` | Old SSR names |
| `sensor.singularity_ntc1_rims_raw` / `ntc2_mash_raw` | Old RAW sensors removed |
| `sensor.singularity_ds18b20_boil_raw` / `hlt_raw` | Old RAW sensors removed |
| `sensor.singularity_debug_0x49_a0_raw` | Old ADS1115 #2 debug sensor |
| `sensor.singularity_firmware_version` | Renamed to `sensor.singularity_build` |
| `sensor.singularity_hlt_temperature` / `ds18b20_kettle` | Old sensor names |
| `sensor.singularity_version` / `newest_version` / `cpu_percent` / `memory_percent` | Old project entities |
| `binary_sensor.singularity_running` / `project_singularity_running` | Old project entities |
| `switch.singularity` / `switch.project_singularity` | Old project switch |
| `update.singularity_firmware` / `singularity_update` / `project_singularity_update` | Old update entities |

---

## Dashboard Version History

| Version | Change |
|---|---|
| v1.0.0 | Initial dashboard |
| v1.0.5 | RIMS simplified to single PID card |
| v1.0.7 | RIMS toggle switch, setpoint 0-80°C |
| v1.0.8 | Fix stale entity IDs (ssr2→rims_heater) |
| v1.1.0 | Offline warning banner on Settings tab |
| v1.1.1 | Default values on Settings entities |
| v1.2.0 | apexcharts-card — 4 sensors, live setpoint line |
| v1.2.1–v1.2.4 | Mushroom template cards, colour thresholds per sensor |
| v1.3.0 | AN1/AN2 flow mushroom cards + reset buttons in Brewing tab |
| v1.3.1–v1.3.5 | Flow cards grouped, reset as button entities, Board 2 in Hardware tab |
| v1.3.6 | AN1 raw voltage diagnostic sensor added |
| v1.3.7 | Diag tab — AN1 + AN2 raw voltage, flow rate, total, live 5min graphs |
| v1.3.8 | Diag tab: removed graphs, entities only |
| v1.3.9 | PID setpoint: text input box, max 78°C |
| v1.4.0 | Settings tab: RIMS Flow Interlock safety card (`flow_interlock_enable` + `pid_min_flow`) |
| v1.6.0 | Log tab: Activity Log = safety events + UI actions; RIMS Mode added to activity graph. Pairs with firmware v1.1.9 `sensor.singularity_safety_event` (offline-persistent safety trips) |

---

## What HA Does vs What ESP32 Does

```
┌─────────────────────────────┬─────────────────────────────────┐
│  Home Assistant             │  ESP32                          │
├─────────────────────────────┼─────────────────────────────────┤
│  Display temperatures °C    │  Read ADS1115 raw voltages      │
│  Display flow rates L/min   │  Run Steinhart-Hart calculation │
│  Show online/offline status │  Convert flow voltage → L/min   │
│  Store calibration in UI    │  Store calibration in flash     │
│  Control RIMS heater toggle │  Run PID loop every 2s          │
│  Show flow rates + totals   │  Drive SSR2 via slow_pwm        │
│  Log connect/disconnect     │  Apply DS18B20 offsets          │
│  Re-send calibration on     │  Accumulate flow totals         │
│    reconnect                │  Publish uptime heartbeat (1s)  │
│  Run fast-status template   │  Enforce flow + over-temp guards│
│                             │  Detect frozen/stale sensor     │
│                             │  Operates independently of HA   │
└─────────────────────────────┴─────────────────────────────────┘
```

> **Design rule:** HA is display and configuration only. The ESP32 calculates all temperatures and flow rates and runs the brew autonomously — even if HA is offline, rebooting, or unreachable.
