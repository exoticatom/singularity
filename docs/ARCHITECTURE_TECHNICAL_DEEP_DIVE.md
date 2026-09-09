# Technical Deep Dive — singularity Control Architecture

**Firmware:** v1.2.0 · **ESPHome:** 2026.8.1 · **Scope:** ESP32-S3-WROOM-1 N16R8 running autonomous brewing control. Details all signal paths, filtering strategies, safety interlocks, and architectural decisions.

---

## Part 1: Signal Acquisition & Conditioning

### Temperature Sensing — NTC Thermistors (A0, A1)

**Physical circuit:** 10 kΩ fixed resistor in series with NTC; junction feeds ADS1115 A0 (NTC1-RIMS) or A1 (NTC2-MASH). Voltage divider equation: `R_ntc = R_fixed × V / (V_ref − V)`.

**Firmware acquisition chain (per-sensor, 1s interval):**
1. **ADS1115 raw read:** 16-bit single-shot conversion, gain 6.144, ~1 ms settle, 1s update interval.
2. **Voltage bounds guard (lambda):** Reject `V < 0.7V` (floating input) or `V ≥ V_ref` (open circuit). Both conditions return NAN.
3. **Resistance calculation:** `R_ntc = R_fixed × V / (V_ref − V)`. Return NAN if R ≤ 0.
4. **Steinhart–Hart conversion (lambda):** `1/T = A + B·ln(R) + C·(ln(R))³`. Convert to Celsius: `T[°C] = (1/inv_T) − 273.15 + offset`.
5. **Temperature bounds guard (lambda):** Reject `T < 0°C` or `T > 100°C`. Return NAN.
6. **Fine-tune offset (lambda):** Add user-calibrated offset (e.g., −0.3°C if reading 0.3°C high).
7. **EMA filter:** `output = 0.25·new + 0.75·prev` (α = 0.25). Smooths noise, response lag ~3–4s for full step change.

**Why three-stage filtering:**
- **Lambda guards:** Catch disconnected sensors (0.7V → NAN), shorted inputs (V ≥ V_ref → NAN), out-of-range temps (< 0 or > 100°C → NAN) *before* they reach the PID.
- **Offset:** Single-point fine-tune without re-running full 3-point calibration.
- **EMA:** Suppresses 50/60 Hz mains interference (common in brewing environments with pump noise, relay switching).

**Why NOT sliding-average(5):** The firmware uses only lambda + EMA. A sliding-average window would add another ~2s lag (5 readings × 1s interval); EMA is more responsive and suitable for real-time control.

---

### Temperature Sensing — DS18B20 Digital (GPIO 48, 1-Wire)

**Physical circuit:** 4.7 kΩ pull-up to 3.3V on GPIO 48. Two sensors share the same wire, identified by 64-bit ROM address. Data line idles HIGH; each sensor pulls LOW to transmit bits. No ADC needed — each sensor outputs °C directly via the 1-Wire protocol.

**Firmware acquisition chain (1s interval):**
1. **1-Wire bus read:** ESP32 GPIO48 driver clocks each sensor in sequence; CRC-8 validated by ESPHome.
2. **Raw °C reading:** DS18B20 outputs ±0.5°C resolution (factory calibrated).
3. **Offset correction (lambda):** Add user-calibrated offset (e.g., +0.2°C if 0.2°C low).
4. **EMA filter:** `output = 0.25·new + 0.75·prev` (α = 0.25), same as NTC. Response lag ~3–4s.

**Why simpler:** No Steinhart–Hart math needed — the sensor handles the conversion on-chip. Only offset + EMA.

**Multi-sensor resilience:** If Boil sensor fails (CRC error), it goes NAN. The PID continues using NTC1/NTC2 readings. HLT sensor failure is decoupled (not used in the heating loop, only display/logging).

---

### Flow Sensing — SM6004 via 4-20mA Converter (A2, A3)

**Physical circuit:** SM6004 magnetic-inductive flow meter outputs 4–20 mA proportional to flow rate. An external XY-IT0V 4-20mA → 0-3.3V converter bridges to the ADS1115. Calibration: 0V = 0 L/min, 1.743V = 13.20 L/min → **slope = 7.57 L/min per volt**.

**Firmware acquisition chain (two streams per flow sensor):**

**Stream 1 — Display rate (an1_rate / an2_rate):**
1. **ADS1115 raw read A2 (RIMS) or A3 (Sparge):** 1s interval, gain 6.144.
2. **Median spike rejection:** `median: window_size: 5` — take 5 readings, return the middle value. Rejects single HIGH/LOW transients. Adds ~5s wall-clock jitter.
3. **Voltage-to-flow conversion (lambda):** If voltage < 0.01V (noise floor), return 0 L/min. Otherwise: `flow = (V × 7.57) + offset`. Clamp to ≥ 0 L/min.
4. **EMA filter:** `output = 0.25·new + 0.75·prev` (α = 0.25). Total lag from raw read to display: **~4–5 seconds** (5 readings + EMA). Smooth for the dashboard; too slow for safety.

**Stream 2 — Safety voltage (an1_flow_safety_v, internal):**
1. **ADS1115 raw read A2 (only for RIMS interlock):** Same 1s interval.
2. **Median spike rejection:** `median: window_size: 3` — take 3 readings, return middle. Blocks a lone HIGH spike (falsely permitting heat — dangerous); a lone LOW spike trips OFF for one fail-safe cycle.
3. **No EMA filter.** This is deliberate. The interlock needs to see a real flow drop **within ~2 seconds**, not 4–5 seconds.
4. **Flow interlock logic (in the 2s PID loop):** Reads `an1_flow_safety_v` state, converts to L/min via same slope + offset, compares against `pid_min_flow` threshold. If flow drops below threshold while interlock is armed, heater shuts off.

**Why two streams?**
- **Display-smoothed (an1_rate):** Renders a stable, readable trend on the dashboard. Users don't want to see every 0.1 L/min jitter.
- **Safety-fast (an1_flow_safety_v):** Catches sudden pump failures or kinked hoses before the RIMS element scorches the wort. A 4–5 second delay while the element heats with no recirculation flow is unacceptable.

**Timeout guard:** If the safety voltage sensor goes NAN (converter failure), the interlock sees NAN and trips the heater OFF.

---

### AN2 Sparge Flow (Not Yet Wired)

A2 remains unconnected pending the second SM6004 and converter installation. To prevent false readings on the floating input, the firmware guards:
- **an2_rate lambda:** If voltage < 0.15V (typical float level), return 0 L/min. Unconnected inputs drift to ~0.1–0.15V.
- **an2_total:** Template sensor reading the global `an2_total_litres`. Stays at 0 until AN2 is wired and flow is detected.

---

## Part 2: Heating Control Loop

### PID Architecture

**Interval:** Every 2 seconds (dt = 2s). The loop reads NTC1-RIMS temperature and computes the output.

**State variables (persisted in RAM, reset on heater ON/OFF or mode change):**
- `pid_integral`: Accumulated error over time (I term). Anti-windup clamp prevents unbounded growth if Ki is nonzero.
- `pid_last_error`: Previous error, used to compute the derivative (D term).

**Tuning parameters (persisted to flash, live-editable from HA):**
- `pid_setpoint`: Target temperature (default 66°C, max 78°C).
- `pid_kp`: Proportional gain (default 10.0).
- `pid_ki`: Integral gain (default 0.2).
- `pid_kd`: Derivative gain (default 5.0).

**Calculation (lines 1209–1243):**
```cpp
error = setpoint - temp
pid_integral += error * dt  // accumulate error over 2s
if (pid_integral > max_i) pid_integral = max_i  // anti-windup
derivative = (error - pid_last_error) / dt
pid_last_error = error

output = kp * error + ki * pid_integral + kd * derivative
if (output < 0) output = 0.0
if (output > 1.0) output = 1.0  // clamp to 0–100%

slow_pwm.set_level(output)
```

**Output:** Duty cycle 0.0 (off) to 1.0 (100%) sent to GPIO42 slow_pwm every 2s. The SSR modulates its mains load at a 2-second period (e.g., 50% duty = 1s ON, 1s OFF).

**PID reset:** Triggered when:
- Heater switch turns ON (clean start, no stale integral).
- Heater switch turns OFF (clear state, start fresh on next brew).
- Mode changes (PID ↔ DC).

**Logging:** Every cycle logs to serial: `RIMS PID  temp=XX.XXC  err=XX.XX  I=X.XXXX  D=X.XXXX  out=XX.X%`

---

### DC Mode (Fixed-Power Heating)

**When:** `select.singularity_rims_mode = "DC"`.

**Behavior:** Ignore setpoint and PID. Drive SSR at a fixed duty cycle specified by `number.singularity_rims_dc_power` (0–100%, default 80%). Settable from the dashboard or Node-RED.

**Use case:** Heat-up phase before entering a temperature-hold mash. The operator sets DC to 80%, watches temp rise, and switches to PID once mash temp is reached.

**Safety still applies:** All four guards (staleness, NAN, 90°C, flow interlock) run **before** the mode branch. DC mode still respects them.

**Logging:** `RIMS DC   temp=XX.XXC  duty=XX.X%%`

---

## Part 3: Safety Interlocks

All four guards run inside the 2-second PID loop. Each guard evaluation happens in order; the first one that trips short-circuits the entire loop with a `return` statement and publishes a trip message.

### Guard 0: Sensor Staleness Watchdog

**Why needed:** The ADS1115 won't return NAN if the I2C bus wedges — it just returns the last value forever. A stuck sensor reading would defeat the NAN guard and the 90°C guard.

**Mechanism:**
- Every time `sensor.singularity_ntc1_rims` publishes a fresh value (1s interval), a lambda stamps the current `millis()` into the global `ntc1_last_update_ms`.
- In the 2s PID loop, the watchdog calculates `stale_ms = millis() - ntc1_last_update_ms`.
- If `stale_ms > 8000` (no fresh read for >8 seconds), trip: heater OFF, publish "Sensor stale — heater OFF", return.

**Why 8s threshold:** NTC updates every 1s. An 8s gap = 8 missed readings — almost certain I2C bus failure, not transient jitter.

**Fault scenario:** JTAG probe accidentally pulls SDA/SCL LOW during a brew; I2C locks up. NTC1 freezes at, say, 67°C. Without this guard, PID would trust 67°C forever and keep heating. With the guard, after 8s the heater cuts off and logs the stale event.

---

### Guard 1: NAN Guard

**When triggered:** The NTC1 lambda returns NAN due to:
- Disconnected sensor (V → 0V, below 0.7V guard → NAN).
- Shorted sensor (V ≥ V_ref → NAN).
- Calculated temperature out of range (< 0°C or > 100°C → NAN).

**Mechanism:** If `std::isnan(temp)` is true, heater OFF, publish "Sensor fault (NAN) — heater OFF", return.

**Immediacy:** Happens within the 2s loop. Heater OFF within 2–3 seconds of sensor failure.

---

### Guard 2: Over-Temperature Hard Limit

**When triggered:** `temp > 90.0°C`.

**Mechanism:** If the NTC1 reading exceeds 90°C, heater OFF, publish "Over-temp >90°C — heater OFF", return.

**Why 90°C:** 
- Mash brewing is typically 66–78°C (PID setpoint max is 78°C).
- Any reading > 90°C suggests pump failure (no recirculation) or sensor fault (stuck reading).
- RIMS element surface can exceed wort temp; 90°C wort is alarm-level hot without active recirculation.

**Residence time:** Even at maximum heat-up rate, a legitimate brew would take tens of seconds to approach 90°C. A sudden spike to 90°C (or a stuck 90°C reading) is caught within one 2s cycle.

---

### Guard 3: RIMS Flow Interlock (Dry-Fire Protection)

**When armed:** `switch.singularity_flow_interlock_enable = ON`.

**Default:** OFF until AN1 (RIMS flow) is commissioned against the SM6004 display.

**Mechanism (lines 1172–1187):**
1. Read the fast safety voltage: `float sv = id(an1_flow_safety_v).state`.
2. Convert to flow rate: `flow = (sv × 7.57) + offset`. If sv is NAN, flow is NAN.
3. Compare: `if (flow < pid_min_flow)` or `std::isnan(flow)`, trip: heater OFF, publish "Low flow — heater OFF", return.

**Why this exists:** A RIMS element heats wort flowing through a narrow tube. If the pump fails, the tube can scorch/caramelize the wort within seconds. The 90°C guard is too slow — by the time NTC1 reads 90°C, the element surface may already be destroying the wort at 140°C+.

**Why not use the display-smoothed an1_rate:**
- `an1_rate` = `median(5) + EMA(α=0.25)` ≈ 4–5 second lag from a real flow drop.
- `an1_flow_safety_v` = `median(3)`, no EMA ≈ ~2 second lag.
- A 4–5 second window is too long. With the element at 100% power, 5 seconds of dry heating can scorch the element.

**Commissioning steps:**
1. Physically connect AN1 flow meter to the SM6004 display.
2. Run RIMS flow at steady state (e.g., 8 L/min) and note the SM6004 display reading.
3. Compare to `sensor.singularity_an1_rate` in HA.
4. Adjust `number.singularity_an1_flow_offset` so HA matches the SM6004 display.
5. Turn ON `switch.singularity_flow_interlock_enable`.
6. Set `number.singularity_pid_min_flow` to the minimum acceptable flow (default 2 L/min).
7. Interlock is now armed; heater will shut off if flow drops below threshold.

---

### Recovery & All-Clear State

**Condition:** All four guards pass (no trip).

**Behavior (lines 1192–1193):** Edge-guarded publish to `sensor.singularity_safety_event` = "OK — heating" (only if the current state is not already "OK — heating"). Prevents spamming the logbook every 2s; recovery is logged once.

**Boot state:** On startup, the `on_boot` handler publishes "Boot — controller started" to the logbook, recording when the device came online.

---

## Part 4: Flash Persistence & Autonomy

### Restore-Value Strategy

Every tuning parameter uses `restore_value: true` + an `initial_value`:

```yaml
- platform: template
  name: "PID Kp"
  id: pid_kp
  restore_value: true         # survives power loss
  initial_value: 10.0         # used only on first boot
```

**First boot:** Initial values are loaded.

**Subsequent boots:** Last user-set values are restored from NVS (flash).

**User edit (from HA):** New value is sent to ESP32, saved to flash, used immediately. No reboot needed.

**Power loss mid-brew:** On next boot, ESP32 resumes with the same tuning parameters.

**Result:** The controller is **self-sufficient** after initial calibration. HA downtime, WiFi outage, or power cut cannot degrade the brew.

---

### API Timeout & Autonomy

`api: reboot_timeout: 0s` means the ESP32 will **never** reboot just because HA is unreachable:

```yaml
api:
  encryption:
    key: !secret singularity_api_encryption_key
  reboot_timeout: 0s  # no HA? keep going
```

**Default behavior (non-zero reboot_timeout):** If HA is unreachable for >Xs, ESP32 reboots to reset the connection. This is standard for "dumb" devices that rely on HA to function. Rebooting mid-brew would stop the heater and reset PID state.

**Singularity behavior (reboot_timeout: 0s):** If HA is unreachable, ESP32 keeps running the PID loop indefinitely. The brew continues uninterrupted. When HA comes back online, the controller re-connects and uploads new readings.

**Caveat:** WiFi self-healing is unchanged. If WiFi itself fails (not just HA), the ESP32 will still attempt WiFi reconnection per the `wifi:` block settings (default ~15 min retry). But a temporary HA software outage doesn't reboot the hardware.

---

## Part 5: Offline-Persistent Logging

**Challenge:** Safety events and user actions occur on the ESP32 and are logged to the serial console (ephemeral — lost on power cut). The HA logbook is persistent (on the Pi's database), but HA is not always online.

**Solution:** The ESP32 publishes every significant event to a **text_sensor** entity that HA records in its logbook, independent of whether HA is reachable at publication time:

| Event | Entity | When published |
|---|---|---|
| Safety trip (stale, NAN, over-temp, low-flow) | `sensor.singularity_safety_event` | Inside the 2s PID loop, edge-guarded |
| All-clear recovery | `sensor.singularity_safety_event` | Inside the 2s PID loop, edge-guarded |
| Boot | `sensor.singularity_safety_event` | `on_boot` handler |
| AN1 flow reset | `sensor.singularity_an1_reset_event` | Button press lambda |
| AN2 flow reset | `sensor.singularity_an2_reset_event` | Button press lambda |
| Setpoint / Kp / Ki / Kd change | (implicitly logged) | `number:` on_value handler logs to serial |
| Calibration change | (implicitly logged) | `number:` on_value handler logs to serial |
| Heater PWM duty | `sensor.singularity_rims_heater_pwm_duty` | Every 2s from the PID loop |
| WiFi signal strength | `sensor.singularity_wifi_signal` | Every 60s from the ESP32 |

**Persistence:** When HA comes online (or if it was already online), the HA recorder automatically stores state changes to the local database. The `logbook:` UI in Home Assistant displays these changes as a timeline.

**Offline availability:** If the ESP32 reboots while HA is offline, the boot message will queue and be logged once HA comes back. The HA recorder uses `last_changed` timestamps, so events are displayed in chronological order even if published out-of-order due to outages.

---

## Part 6: Firmware Boot Sequence

**Priority: -100 (runs last, after all hardware is initialized):**

```cpp
on_boot:
  priority: -100
  then:
    - lambda: |-
        ESP_LOGI("singularity", "=== BOOT — Active Parameters (from flash) ===");
        // Log all current NTC, DS18B20, PID, mode, relay parameters
        ESP_LOGI("singularity", "...");
        id(safety_event).publish_state("Boot — controller started");
```

**Printout includes:**
- NTC1/NTC2 R, V-ref, S-H coefficients, offset.
- DS18B20 offsets.
- PID setpoint, Kp, Ki, Kd.
- RIMS mode (PID or DC).
- DC power %.
- RIMS heater switch state.
- SSR1 switch state.
- AN1/AN2 flow offsets.
- The boot message is published to the logbook.

**Purpose:** Verify that all calibration values have been restored from flash correctly. This printout is visible in the serial console and the HA `Developer Tools → Logs` UI.

---

## Part 7: Architectural Decisions & Rationale

### Why single ADS1115 (not two)?

Second ADS1115 (0x49) was tested and rejected due to **voltage drift**: two units were evaluated; one drifted negative below GND, the other drifted positive to ~0.58V even with no input connected. The positive drift produced false temperature readings (~64°C from a floating input), which could deceive the PID into dangerous heating levels. All four channels fit on one chip; using a second chip added risk without benefit. Documented in hardware/README.md line 251 and gpio_map.md line 115.

### Why slow_pwm 2-second period (not PWM)?

SSRs (Solid-State Relays) use semiconductor outputs (not mechanical contacts) to switch AC mains load. They switch ON at the AC zero-crossing and OFF at the next zero-crossing, to reduce switching noise. Typical AC mains is 50/60 Hz, so one cycle is ~16–20 ms. A typical DC motor PWM at 1–20 kHz would cause the SSR to switch on every few microseconds, rapidly degrading the semiconductor junction through thermal cycling. **slow_pwm** with a 2-second period (much slower than the AC cycle) is the standard approach for SSR load control in brewing applications. 50% duty at 2s period = 1s ON, 1s OFF.

### Why reboot_timeout: 0s?

A brew in progress **must not** be interrupted by an HA software update, a network blip, or a container restart on the Pi. The PID loop and safety interlocks run on the ESP32 and must survive. Setting reboot_timeout to 0s ensures the ESP32 never auto-reboot just because HA is unreachable. Network and WiFi recovery is still handled (standard retry logic). But if HA stays offline for 1 hour, the brew finishes normally — no interruption.

### Why edge-guarded safety_event publishes?

Without edge-guarding, if the staleness guard trips at T=2s, 4s, 6s, 8s, 10s (every 2-second cycle that staleness persists), the logbook would record "Sensor stale" five times in 10 seconds, making the log hard to read. With edge-guarding, "Sensor stale" is logged once when the guard first trips. When recovery occurs (sensor resumes updating), "OK — heating" is logged once. This makes the timeline clear: event → recovery (or not).

---

*This deep-dive is reference material for firmware developers and advanced users. Refer to the one-line comments in `esp32_singularity.yaml` for inline documentation.*
