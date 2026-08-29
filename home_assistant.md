# singularity — Home Assistant Integration

> ← Back to **[README.md](README.md)**

This page documents everything that was configured in [Home Assistant](https://www.home-assistant.io) for the singularity brewing controller — entities, automations, templates, dashboard, and how they all connect.

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
                │  singularity v1.0.8 │
                │  192.168.168.178    │
                └─────────────────────┘
```

---

## Entity Map

All singularity entities in [Home Assistant](https://www.home-assistant.io) — what they do and where they come from:

### Sensors (read-only, from ESP32)

```
sensor.singularity_ntc1_rims        °C    NTC1 on ADS1115 A0 — RIMS tube temp (S-H calc on ESP32)
sensor.singularity_ntc2_mash        °C    NTC2 on ADS1115 A1 — Mash tun temp (S-H calc on ESP32)
sensor.singularity_ds18b20_boil     °C    DS18B20 on 1-Wire GPIO48 (offset applied on ESP32)
sensor.singularity_ds18b20_hlt      °C    DS18B20 on 1-Wire GPIO48 (offset applied on ESP32)
sensor.singularity_build            str   Firmware version string (e.g. "v1.0.8") — updates every 10s
sensor.singularity_uptime           s     Seconds since last boot — updates every 1s (heartbeat)
sensor.singularity_wifi_signal      dBm   WiFi RSSI — updates every 60s (diagnostic)
```

### Binary Sensors

```
binary_sensor.singularity_esp32_status      on/off   Native ESPHome connectivity (slow — ~30-60s)
binary_sensor.singularity_esp32_fast_status  on/off   Template sensor — offline within 10s (see below)
```

### Number Entities (read/write, persisted on ESP32 flash)

```
NTC1-RIMS Calibration:
  number.singularity_ntc1_r_fixed      Ω     Fixed resistor value (default: 9883)
  number.singularity_ntc1_v_ref        V     Reference voltage (default: 3.3)
  number.singularity_ntc1_sh_a               S-H coefficient A (default: 1.207e-3)
  number.singularity_ntc1_sh_b               S-H coefficient B (default: 2.183e-4)
  number.singularity_ntc1_sh_c               S-H coefficient C (default: 1.764e-7)
  number.singularity_ntc1_offset       °C    Single-point offset (default: 0.0)

NTC2-MASH Calibration:
  number.singularity_ntc2_r_fixed      Ω     Fixed resistor value (default: 9902)
  number.singularity_ntc2_v_ref        V     Reference voltage (default: 3.3)
  number.singularity_ntc2_sh_a               S-H coefficient A (default: 1.210e-3)
  number.singularity_ntc2_sh_b               S-H coefficient B (default: 2.173e-4)
  number.singularity_ntc2_sh_c               S-H coefficient C (default: 1.848e-7)
  number.singularity_ntc2_offset       °C    Single-point offset (default: 0.0)

DS18B20 Offsets:
  number.singularity_ds18b20_boil_offset  °C  Offset for Boil sensor (default: 0.0)
  number.singularity_ds18b20_hlt_offset   °C  Offset for HLT sensor (default: 0.0)

PID Control:
  number.singularity_pid_setpoint      °C    Target temperature (default: 66.0, range 0-80)
  number.singularity_pid_kp                  Proportional gain (default: 10.0)
  number.singularity_pid_ki                  Integral gain (default: 0.2)
  number.singularity_pid_kd                  Derivative gain (default: 5.0)
  number.singularity_pid_max_duty_cycle  %   Heater output cap (default: 100)
```

### Switches (read/write, persisted on ESP32 flash)

```
switch.singularity_rims_heater    ON/OFF   Enables PID control loop → SSR2 (GPIO42)
switch.singularity_ssr1           ON/OFF   SSR1 direct control (GPIO41)
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
  binary_sensor.esp32_fast_status
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

---

## Dashboard

**File:** `singularity_dashboard.yaml` → deployed to `/config/singularity_dashboard.yaml`  
**Version:** v1.2.0  
**Registered in:** `/config/configuration.yaml` as `lovelace` dashboard

### Tab layout

```
┌─────────────────────┬──────┬──────────┬───────┬──────────┐
│  🌡️ Brewing Temps   │  📋  │  ⚙️       │  ℹ️   │  🔌      │
│     (main)          │ Log  │ Settings │ About │ Hardware │
└─────────────────────┴──────┴──────────┴───────┴──────────┘
```

### Tab 1 — Brewing Temperatures

```
┌────────────────────────────────────────────┐
│  🟢 singularity.local — Online             │  ← conditional (ESP32 online)
│  🔴 singularity.local — Offline ⚠️         │  ← conditional (ESP32 offline)
├──────────────────┬─────────────────────────┤
│ 🌡️ NTC1-RIMS     │ 🌡️ NTC2-MASH            │  ← mushroom cards, colour by temp
│  67.3 °C (green) │  65.8 °C (green)        │    <50 blue, 50-69 green
├──────────────────┼─────────────────────────┤    69-75 orange, >75 red
│ 🌡️ DS18B20-Boil  │ 🌡️ DS18B20-HLT          │  ← boil: <92 blue, <99 orange, ≥99 red
│  98.2 °C (orange)│  72.4 °C (orange)       │    HLT:  <50 blue, <70 green
├────────────────────────────────────────────┤    70-85 orange, >85 red
│  RIMS Heater [toggle]  Target Temp [slider]│
├────────────────────────────────────────────┤
│  📈 apexcharts — 4 sensors + setpoint line │
│     1h span, 5s refresh, 0-100°C           │
└────────────────────────────────────────────┘
```

### Tab 2 — Log

```
┌────────────────────────────────────────────┐
│  ⚠️ ESP32 is offline  (conditional)        │
├────────────────────────────────────────────┤
│  Activity Log (logbook 24h)                │
│  • ESP32 connect/disconnect events         │
│  • Firmware version changes               │
├────────────────────────────────────────────┤
│  SSR / RIMS Activity (history-graph 24h)   │
│  • SSR1 state  • RIMS Heater state         │
└────────────────────────────────────────────┘
```

### Tab 3 — Settings

```
┌────────────────────────────────────────────┐
│  ⚠️ ESP32 is offline — settings not        │
│  readable until reconnect (conditional)    │
├────────────────────────────────────────────┤
│  How calibration works                     │
├────────────────────────────────────────────┤
│  DS18B20 Offsets                           │
│  • DS18B20-Boil Offset (default: 0.0°C)   │
│  • DS18B20-HLT Offset  (default: 0.0°C)   │
├────────────────────────────────────────────┤
│  NTC1-RIMS — Steinhart-Hart Calibration    │
│  • R-Fixed  • V-Ref  • A  • B  • C        │
│  • Offset                                  │
├────────────────────────────────────────────┤
│  NTC2-MASH — Steinhart-Hart Calibration    │
│  • R-Fixed  • V-Ref  • A  • B  • C        │
│  • Offset                                  │
├────────────────────────────────────────────┤
│  RIMS Heater — PID Control                 │
│  • [toggle]  RIMS Heater                   │
│  • Setpoint  Kp  Ki  Kd  Max Duty         │
├────────────────────────────────────────────┤
│  How calibration works (offline behaviour) │
└────────────────────────────────────────────┘
```

### Tab 4 — About

```
┌────────────────────────────────────────────┐
│  ⚠️ ESP32 is offline  (conditional)        │
├────────────────────────────────────────────┤
│  System Versions                           │
│  🔧 ESP32 Firmware  │  v1.0.8  │  ● Live  │
│  📊 Dashboard       │  v1.2.0  │  ● Live  │
├────────────────────────────────────────────┤
│  About singularity                         │
│  Sensor map, GPIO assignments              │
└────────────────────────────────────────────┘
```

### Tab 5 — Hardware

```
┌────────────────────────────────────────────┐
│  ⚠️ ESP32 is offline  (conditional)        │
├────────────────────────────────────────────┤
│  ESP32-S3-DEV-KIT-NXRX — Board Overview   │
│  [board image]                             │
├────────────────────────────────────────────┤
│  ESP32-S3 Pinout                           │
│  [pinout image]                            │
├────────────────────────────────────────────┤
│  Pin Assignments table                     │
│  I2C Device Map table                      │
└────────────────────────────────────────────┘
```

---

## Configuration Files on Pi

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
# Connect/disconnect events are still logged via binary_sensor state changes.
recorder:
  exclude:
    entities:
      - sensor.singularity_uptime      # 1s heartbeat — not useful as history
      - sensor.singularity_wifi_signal # 60s diagnostic — not useful as history
```

---

## Reconnect Automation

When the ESP32 reconnects after any outage, HA automatically re-sends all 14 calibration values. This keeps ESP32 flash in sync with whatever was last set in the dashboard.

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

> **Note:** Values are already on ESP32 flash and applied immediately on boot. The automation is a safety net — if someone changed a value in HA while the ESP32 was offline, this ensures it gets applied. PID parameters (Setpoint, Kp, Ki, Kd, Max Duty) are not re-pushed — they also persist on ESP32 flash independently.

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

## Dashboard Version History

| Version | Change |
|---|---|
| v1.0.0 | Initial dashboard |
| v1.0.3 | PID parameters card in Settings tab |
| v1.0.4 | RIMS dual-mode control cards |
| v1.0.5 | RIMS simplified to single PID card |
| v1.0.6 | RIMS mode select + setpoint on main tab |
| v1.0.7 | RIMS toggle switch, setpoint 0-80°C |
| v1.0.8 | Fix stale entity IDs (select→switch, ssr2→rims_heater) |
| v1.0.9 | Remove stale HA Templates row |
| v1.1.0 | Offline warning banner on Settings tab |
| v1.1.1 | Default values on Settings entities |
| v1.1.3 | Default values in entity names |
| v1.1.5 | Long coefficients as secondary_info |
| v1.1.6 | Calibration sections in hardware docs + links |
| v1.1.7 | Offline ⚠️ banner on Log, About, Hardware tabs |
| v1.1.8 | ⚠️ added to main tab offline banner |
| v1.2.0 | Replace history-graph with apexcharts-card — 4 sensors, live setpoint line, colour coded |
| v1.2.1 | Mushroom template cards for sensors — colour thresholds per sensor type |
| v1.2.2 | DS18B20-Boil thresholds: blue <92°C, orange <99°C, red ≥99°C |
| v1.2.3 | Fix mushroom icon_color whitespace (collapsed to single-line templates) |

---

## What HA Does vs What ESP32 Does

```
┌─────────────────────────────┬─────────────────────────────────┐
│  Home Assistant             │  ESP32                          │
├─────────────────────────────┼─────────────────────────────────┤
│  Display temperatures       │  Read ADS1115 voltages          │
│  Show online/offline status │  Run Steinhart-Hart calculation │
│  Store calibration in UI    │  Store calibration in flash     │
│  Control RIMS heater toggle │  Run PID loop every 2s          │
│  Show PID setpoint input    │  Drive SSR2 via slow_pwm        │
│  Log connect/disconnect     │  Apply DS18B20 offsets          │
│  Re-send calibration on     │  Publish uptime heartbeat (1s)  │
│    reconnect                │  Publish WiFi RSSI (60s)        │
│  Run fast-status template   │  Works standalone after flash   │
└─────────────────────────────┴─────────────────────────────────┘
```

> **Design rule:** HA is display and configuration only. The ESP32 runs the brew even if HA is offline.
