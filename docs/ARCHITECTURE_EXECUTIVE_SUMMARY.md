# singularity — Executive Summary

**What is singularity?** An autonomous ESP32-S3 brewing controller that runs locally on hardware, continues operating even if Home Assistant goes offline, and integrates with HA for display and configuration.

**Key differentiator:** The control loop and **all safety interlocks run on the ESP32 every 2 seconds**. HA is supervisory display + config only. A HA outage or network loss does **not** interrupt an active brew.

---

## The System in One Diagram

```
┌────────────────────────────────────────────┐
│  Home Assistant (Raspberry Pi)             │ ← optional
│  Dashboard, settings, logbook              │   (not
│                                            │    required
│  ← WiFi → ↔ ESPHome native API (encrypted)│    for
│                                            │    brewing)
└────────────────┬───────────────────────────┘
                 │
        ┌────────▼─────────┐
        │  ESP32-S3-WROOM  │ ← runs autonomously
        │  (N16R8)         │   even offline
        │                  │
        │  • PID loop (2s) │
        │  • 4 safety guards
        │  • NTC S-H math  │ embedded in C++
        │  • Flow totals   │
        │  • All state on flash
        │                  │
        ├─ GPIO42 → SSR2 → RIMS heater (2s PWM)
        ├─ GPIO41 → SSR1 → spare relay
        ├─ GPIO21/47 (I²C) → ADS1115 ADC
        │  ├─ A0: NTC1-RIMS temp
        │  ├─ A1: NTC2-MASH temp
        │  ├─ A2: AN1 RIMS flow (+ fast safety bypass)
        │  └─ A3: AN2 Sparge flow (not wired yet)
        │
        └─ GPIO48 (1-Wire) → DS18B20 × 2
           ├─ Boil kettle temp
           └─ HLT temp
```

---

## Current Operating Model

**User controls (from HA dashboard or Node-RED, future):**

| Control | Scope | Current state |
|---------|-------|---|
| RIMS Heater (ON/OFF) | Enable/disable the PID loop | Manual toggle |
| RIMS Mode (PID/DC) | Closed-loop setpoint vs. fixed power | Manual select |
| PID Setpoint (°C) | Target temperature for closed-loop | Manual slider, 0–78°C |
| PID Tuning (Kp/Ki/Kd) | Closed-loop response characteristics | Manual numbers, flash-persisted |
| DC Power (%) | Fixed heater duty in DC mode | Manual slider, 0–100%, default 80% |
| Flow Interlock | Arm dry-fire protection | Manual toggle (default OFF until AN1 commissioned) |
| Flow Min Threshold (L/min) | Minimum RIMS recirculation required | Manual number, default 2.0 L/min |
| Flow Totals Reset | Zero per-brew counters | Manual buttons |

**Automatic (ESP32, every 2 seconds):**
- Read NTC1-RIMS, compare to setpoint, compute PID or DC output.
- Enforce 4 safety guards: staleness (>8s), NAN (disconnected), over-temp (>90°C), low-flow (if armed).
- Publish temperatures, flow rates, PWM duty, and safety events to HA logbook.
- All parameters survive power loss.

**Future (Node-RED, planned):**
- Brew phase sequencing (Strike → Mash → Sparge → Boil).
- Automated temperature hold and ramp profiles.
- Mash step timers.
- Not built yet. Will drive the manual controls above over the HA API.

---

## Safety Model

**Primary:** 4-tier interlock chain inside the 2s PID loop.

| Guard | Condition | Action | Logbook msg |
|-------|-----------|--------|--|
| 0 | NTC1 stale >8s (I²C wedged) | Heater OFF | "Sensor stale" |
| 1 | NTC1 = NAN (disconnected) | Heater OFF | "Sensor fault (NAN)" |
| 2 | NTC1 > 90°C | Heater OFF | "Over-temp >90°C" |
| 3 | Flow < min (when armed) | Heater OFF | "Low flow" |
| — | All pass | Heat normally | "OK — heating" |

**Secondary (hardware, REQUIRED before live heating tests):** An independent bimetallic thermal cutoff (~90–95°C) or thermal fuse, wired in series with the SSR AC mains line and clamped to the RIMS element body. Independent of the ESP32; protects if firmware hangs or GPIO is stuck.

**Connectivity:** 1-second uptime pulse feeds a 10-second HA disconnect watchdog. HA logbook records all events with timestamps, even if the ESP32 is offline.

---

## Hardware Snapshot

| Subsystem | Component | Notes |
|-----------|-----------|-------|
| MCU | ESP32-S3-WROOM-1 N16R8 | 16 MB flash, 8 MB PSRAM, Arduino framework |
| Analog I/O | 1× ADS1115 @ 0x48 | Single-shot, 16-bit, ±6.144V. A0/A1 (NTC), A2/A3 (flow). Second chip (0x49) rejected due to voltage drift. |
| Temperature | 2× NTC 10kΩ (S-H calibrated) | A0 = RIMS outlet, A1 = mash tun. Voltage divider → ADS1115. |
| — | 2× DS18B20 (1-Wire) | Boil kettle, HLT. GPIO48. |
| Flow | 2× SM6004 flow meters | A2 (RIMS) wired + commissioned; A3 (Sparge) planned. Via 4-20mA→0-3.3V converters. Slope = 7.57 L/min per volt. |
| Heating | SSR2 (GPIO42, slow_pwm 2s) | RIMS element. 10kΩ gate pulldown (boot safety). |
| — | SSR1 (GPIO41) | Spare relay. 10kΩ gate pulldown. |
| Compute | Flash persistence | All calibration (NTC S-H, DS18B20 offset, PID Kp/Ki/Kd) stored on ESP32; survives power loss. |
| — | Autonomy | `api: reboot_timeout: 0s` → HA outage never halts a brew. |

---

## What's Built vs. Planned

✅ **Working now:**
- ESP32 autonomous heating control (PID + DC modes).
- All 4 safety interlocks.
- Temperature + flow sensing and logging.
- Flash persistence (calibration survives power loss).
- HA integration (display, parameter tuning, offline logbook).
- An1 RIMS flow commissioned + flowing.

🔄 **In progress / pending:**
- **Hardware thermal cutoff** (required before live load tests; external install).
- AN2 Sparge flow wiring.
- Hardware high-limit thermal fuse installation.

📋 **Planned (not started):**
- Node-RED brew sequencing (Idle → Strike → Mash → Sparge → Boil).
- Dynamic `input_select` sensor routing.
- MCP4728 proportional valve DAC.
- MCP23017 relay expander.

---

## Key Architectural Rules

1. **ESP32 is the brain.** Calculations (S-H, PID, flow conversion), state (calibration), and safety interlocks run locally in C++ on the MCU. Not a dumb sensor node.
2. **HA is supervisory.** Display, settings UI, logbook persistence. HA unreachable does not degrade the brew.
3. **Safety is local.** All 4 guards evaluate inside the 2s PID loop, on the ESP32. No remote dependencies.
4. **Flash persistence.** Calibration survives power cuts. After the first calibration, the system is self-sufficient.
5. **Offline logging.** Safety events and user actions are published to HA logbook entities, which persist even if ESP32 is offline when HA comes back.

---

## How to Use (Basic Workflow)

1. **Setup:** Calibrate NTC (Steinhart–Hart), DS18B20 offsets, ADS1115 gain.
2. **Commission flow meter:** Verify AN1 flow reading against SM6004 display; adjust offset.
3. **Arm interlock:** Turn ON `flow_interlock_enable` switch.
4. **Start brew:**
   - Set RIMS Heater to ON.
   - Set RIMS Mode to DC; set DC Power to 80%.
   - Watch temperature rise via the dashboard.
   - When near mash temp, switch RIMS Mode to PID.
   - Set PID Setpoint to target (e.g., 67°C).
   - PID loop takes over; heater modulates to hold setpoint.
5. **Monitor:** Dashboard shows live temps, flow rates, PWM duty, safety events (logbook tab).

---

## Known Limitations & Gaps

- **Single-point-of-failure in firmware:** All thermal protection lives in the ESP32 code. A firmware hang or stuck GPIO defeats every software guard. **Mitigation:** Independent hardware thermal cutoff (bimetallic or fuse) wired in series with the mains load. **Status:** Required before first load test; external install.
- **No remote sequencing yet:** Manual control only; Node-RED state machine is planned but not implemented.
- **AN2 Sparge flow not wired:** Second flow sensor not yet commissioned.
- **Firmware v1.2.0 compiled but not flashed:** Running hardware is on older build. New features (PWM duty logging, safety event bridge, calibration reset buttons, etc.) are ready for OTA deployment once tested.

---

## For More Detail

- **Full design spec:** [`docs/ARCHITECTURE.md`](ARCHITECTURE.md)
- **Technical deep-dive:** [`docs/ARCHITECTURE_TECHNICAL_DEEP_DIVE.md`](ARCHITECTURE_TECHNICAL_DEEP_DIVE.md)
- **Verification checklist:** [`docs/ARCHITECTURE_VERIFICATION.md`](ARCHITECTURE_VERIFICATION.md)
- **Electrical schematic:** [`schematics/schematic.md`](../schematics/schematic.md)
- **Hardware docs:** [`hardware/`](../hardware/)
- **Firmware source:** [`esp32_singularity.yaml`](../esp32_singularity.yaml)

---

**Firmware:** v1.2.0 · **ESPHome:** 2026.8.1 · **Last updated:** 2026-09-09
