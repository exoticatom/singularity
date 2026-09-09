# singularity — Project Architecture & Status Summary

**Role of this document:** single source of truth for the system's design, compute placement, and safety posture. Cross-referenced against the live source — [`esp32_singularity.yaml`](../esp32_singularity.yaml) (firmware v1.2.0), [`singularity_dashboard.yaml`](../singularity_dashboard.yaml), [`hardware/gpio_map.md`](../hardware/gpio_map.md), and [`home_assistant.md`](../home_assistant.md).

**Project:** singularity brewing controller · **Firmware:** v1.2.0 · **ESPHome:** 2026.8.1 · **Last updated:** 2026-09-09

---

## ⚠️ Reconciling the brief with the codebase

Five premises commonly stated about this system do **not** match what the source actually does. This document corrects them up front so the "single source of truth" is grounded in the running firmware, not the mental model.

| # | Common premise | Ground truth in the code |
|---|---|---|
| 1 | "The ESP32 is a dumb I/O device; Home Assistant is the brain." | **Inverted.** The ESP32 is autonomous: it runs the Steinhart–Hart math, the full PID loop, and every safety interlock on-device every 2 s. HA is display + configuration only. `api: reboot_timeout: 0s` means an HA outage never even interrupts a brew. |
| 2 | "Temperature is computed in HA templates." | **False.** Steinhart–Hart (`1/T = A + B·ln R + C·(ln R)³`) runs in the ESP32 sensor lambda (`esp32_singularity.yaml`, NTC1/NTC2 filters). HA never sees raw voltage-to-°C math. |
| 3 | "Dynamic sensor routing via `input_select` is implemented." | **Planned, not built.** The only routing control that exists is `select.singularity_rims_mode` (PID vs DC). There is no input_select-driven sensor multiplexing in firmware. |
| 4 | "A Node-RED state machine sequences the brew (Idle→Strike→Mash→Sparge→Boil)." | **Does not exist.** No such flow is in the repo. Node-RED is a planned orchestration layer. Today the ESP32 exposes primitives (mode select, setpoint, DC power, switches) that a future Node-RED layer can drive via the HA API. |
| 5 | "Connectivity is tracked by `sensor.singularity_system_uptime`." | **Wrong entity.** It is `sensor.singularity_uptime` (1 s heartbeat) feeding `binary_sensor.singularity_esp32_fast_status`, which flips offline after >10 s of no update. |

**Design axiom that follows:** *Calculations and state that must survive a reboot live on the ESP32. Configuration and display live in HA. Sequences and scheduling live in Node-RED (planned).*

---

## 1. Hardware Foundation

| Element | Detail | Source |
|---|---|---|
| MCU | ESP32-S3-WROOM-1 (DevKitC-1, N16R8 — 16 MB flash / 8 MB PSRAM), Arduino framework | `esp32:` block |
| ADC | **Single** ADS1115 16-bit at `0x48` (ADDR→GND), single-shot mode, gain 6.144 | `ads1115:` block |
| I²C bus | SDA = GPIO21, SCL = GPIO47, `scan: true` | `i2c:` block |
| 1-Wire | GPIO48, 4.7 kΩ pull-up; 2× DS18B20 | `one_wire:` block |
| SSR1 (spare) | GPIO41 gpio switch, `RESTORE_DEFAULT_OFF`, 10 kΩ gate pulldown | `switch:` |
| SSR2 (RIMS heater) | GPIO42 `slow_pwm`, 2 s period, 10 kΩ gate pulldown | `output:` |

**ADS1115 channel map:**

| Ch | Signal | Entity | Notes |
|---|---|---|---|
| A0 | NTC1-RIMS | `sensor.singularity_ntc1_rims` | RIMS tube outlet temp |
| A1 | NTC2-MASH | `sensor.singularity_ntc2_mash` | Mash tun temp |
| A2 | AN1 (RIMS flow) | `sensor.singularity_an1_rate` + `an1_flow_safety_v` (internal) | SM6004 #1 via 4-20mA→0-3.3V |
| A3 | AN2 (Sparge flow) | `sensor.singularity_an2_rate` | SM6004 #2 — **not yet wired** (0.15 V float guard) |

**DS18B20 ROMs (installation-specific):** Boil `0x750000105cbe3528`, HLT `0x3100000c31dd5a28`.

**Board-count decision:** a second ADS1115 at `0x49` was tested and **rejected** (voltage drift). All four channels fit on the one chip at 0x48; only one ADC is on the bus.

**Boot-safety hardware:** 10 kΩ pulldowns on GPIO41/42 hold the SSR gates LOW through reset/boot — the window before firmware runs, which `RESTORE_DEFAULT_OFF` cannot cover. Neither pin is a strapping pin, so the pulldowns don't affect boot mode.

---

## 2. Compute-Location Architecture ("Software Switchboard")

Three tiers, strictly separated:

**Tier 1 — ESP32 (autonomous, reboot-survivable):**
- Steinhart–Hart temperature conversion (NTC1/NTC2), DS18B20 offset correction.
- Flow rate conversion (7.57 L/min per volt slope) + litre accumulation.
- PID loop and DC-mode output, every 2 s (`dt = 2s`).
- **All** safety interlocks (see §4).
- Calibration/tuning parameters persisted to flash (`restore_value: true`) — changeable live from HA, no reflash.
- `api: reboot_timeout: 0s` → HA outage cannot stop or degrade a brew.

**Tier 2 — Home Assistant (display + configuration):**
- Renders dashboard tabs; hosts the recorder DB on the Pi (10-day retention) → offline-persistent logbook.
- Number/select/switch entities push config down to the ESP32.
- `binary_sensor.singularity_esp32_fast_status` derived from `sensor.singularity_uptime` (offline at >10 s).

**Tier 3 — Node-RED (planned):**
- Intended home for brew sequencing/scheduling. Drives the ESP32 primitives (`select.select_option`, `number.set_value`) over the HA API.
- **Not implemented today** — no state machine exists yet.

---

## 3. Process Automation — current reality

There is **no brew state machine**. What exists is a mode primitive plus manual controls:

| Control | Entity | Effect |
|---|---|---|
| RIMS Mode | `select.singularity_rims_mode` = PID \| DC | PID = closed-loop toward `pid_setpoint`; DC = fixed `rims_dc_power` %. Mode change resets PID state. |
| RIMS Heater | `switch.singularity_rims_heater` | Enables the control loop; OFF forces 0 % and resets PID state. |
| DC Power | `number.singularity_rims_dc_power` | Fixed duty in DC mode (default 80 %). |
| Setpoint / Kp / Ki / Kd | `number.singularity_pid_*` | PID tuning, flash-persisted. |
| Flow Interlock | `switch.singularity_flow_interlock_enable` | Arms dry-fire protection (default OFF until AN1 commissioned). |
| Flow totals reset | `button.singularity_an1_reset_total` / `an2_reset_total` | Zero per-session litre counters. |

Sequencing (Strike/Mash/Sparge/Boil) is a **future** Node-RED responsibility.

---

## 4. Safety Mechanisms

All thermal protection lives in the ESP32's 2 s PID loop, evaluated **before** any heating each cycle. Guards short-circuit (force 0 % duty and `return`) and publish an edge-guarded message to `sensor.singularity_safety_event` (offline-persistent via the HA recorder).

| # | Guard | Trip condition | Logbook message |
|---|---|---|---|
| 0 | Staleness watchdog | No fresh NTC1 reading for >8 s (I²C wedged → sensor frozen, not NAN) | `Sensor stale — heater OFF` |
| 1 | NAN guard | NTC1 returns NAN (disconnected/shorted/out-of-range) | `Sensor fault (NAN) — heater OFF` |
| 2 | Over-temp hard limit | NTC1 > 90 °C | `Over-temp >90°C — heater OFF` |
| 3 | Flow interlock | When armed: `an1_flow_safety_v`-derived flow < `pid_min_flow` (or NAN) | `Low flow — heater OFF` |
| — | All clear | Every guard passed | `OK — heating` (edge-guarded, logs recovery) |
| — | Boot | `on_boot` | `Boot — controller started` |

**Why the fast safety voltage exists:** `an1_rate` carries median(5)+EMA(α=0.25) for a stable display (~4-5 s lag) — too slow to catch sudden flow loss before a RIMS element scorches. `an1_flow_safety_v` (internal, median(3), **no EMA**) lets the interlock see a real flow drop within ~2 s. median(3) blocks a lone HIGH spike from falsely permitting heat (the dangerous direction); a lone LOW spike only trips OFF for one fail-safe cycle.

**Filtering:** EMA α = 0.25 (`output = 0.25·new + 0.75·prev`) on all analog inputs including diagnostics; NTC chain adds a lambda + sliding-average(5) stage first.

**Autonomy:** `reboot_timeout: 0s` on the API; PID state resets to a clean start on heater ON, heater OFF, and mode change (never resumes a stale integral).

### ⚠️ Standing safety gap (required before first load test)

All thermal protection today is in **one place** — the ESP32 firmware. That is a single point of failure: a firmware hang, a crashed MCU with the SSR latched, or a GPIO stuck HIGH defeats every software guard at once. A **hardware high-limit cutoff independent of the ESP32** (bimetallic snap-disc / Klixon ~90–95 °C, or a one-shot thermal fuse), clamped to the RIMS element body, must be wired **in series with the SSR AC mains load** — not the control side — and installed **before mains power is connected to the element** and before the first RIMS load test. Planned as a single one-time install. Tracked in [README Project Status](../README.md#project-status) and [`hardware/gpio_map.md`](../hardware/gpio_map.md#ssr-gate-circuit-gpio-41--42--pulldown-required).

---

## 5. Implemented vs. Pending

**Implemented:**
- ESP32 firmware v1.2.0: NTC ×2 (S-H), DS18B20 ×2, AN1/AN2 flow + totals, PID + DC modes, 4-guard safety chain.
- Flash-persisted calibration/tuning; live-editable from HA (no reflash).
- Offline-persistent logging: `safety_event`, `an1/an2_reset_event`, `rims_heater_pwm_duty`, WiFi signal; 24 h Activity Log.
- Fast offline detection (`esp32_fast_status`, 10 s).
- Single-sheet electrical schematic ([`schematics/`](../schematics/schematic.md)).

**Pending / planned:**
- **Independent hardware high-limit cutoff** (safety-critical — blocks first load test).
- AN2 sparge flow wiring + commissioning; arm flow interlock after AN1 verified vs SM6004.
- Node-RED orchestration / brew state machine.
- `input_select`-driven dynamic sensor routing.
- MCP4728 DAC analog outputs; YF-S200 pulse flow (both documented, not wired).
- Firmware v1.2.0 is committed/compiled but **not yet flashed** to the running controller (which is on an older build).

---

*This document reflects the source as of firmware v1.2.0 (2026-09-09). When firmware, dashboard, or hardware docs change, update this file in the same commit so it remains the single source of truth.*
