# singularity — Calibration Guide

This page covers calibration procedures for all sensors and modules in the singularity brewing controller.

---

## Contents

1. [NTC Thermistors — Steinhart-Hart Calibration](#ntc-thermistors--steinhart-hart-calibration)
2. [DS18B20 — Offset Correction](#ds18b20--offset-correction)
3. [ADS1115 — Input Verification](#ads1115--input-verification)
4. [SM6004 + 4-20mA Converter — ZERO/SPAN Calibration](#sm6004--4-20ma-converter--zerospan-calibration)
5. [PID Tuning — RIMS Heater](#pid-tuning--rims-heater)

---

## How calibration values are stored

All calibration values are stored on the **ESP32 flash** using `restore_value: true` — they survive power cuts and reboots without needing HA.

Values take effect within 1 second of being changed in the Settings tab. You can adjust in real-time during a brew — no reflash needed.

**If ESP32 is offline when you change a value:**
- HA stores the new value optimistically
- When ESP32 comes back online, HA automatically re-sends all values within ~3 seconds
- ESP32 saves them to flash and applies them immediately

---

## NTC Thermistors — Steinhart-Hart Calibration

> 🔗 See also: [NTC Thermistors — hardware/ntc.md](ntc.md)

singularity uses the full 3-coefficient Steinhart-Hart equation for accurate temperature conversion:

```
1/T = A + B·ln(R) + C·(ln(R))³
T(°C) = (1/T_kelvin) - 273.15 + offset
R = r_fixed × V / (v_ref − V)
```

### Current calibration values

| Parameter | NTC1-RIMS | NTC2-MASH | Notes |
|---|---|---|---|
| R-Fixed (Ω) | 9883 | 9902 | Measured actual resistor value |
| V-Ref (V) | 3.3 | 3.3 | ESP32 supply voltage |
| A | 0.001207071588 | 0.001209771862 | Steinhart-Hart coefficient |
| B | 0.0002183328996 | 0.0002173461562 | Steinhart-Hart coefficient |
| C | 0.0000001764463641 | 0.0000001848376283 | Steinhart-Hart coefficient |
| Offset (°C) | 0.0 | 0.0 | Fine-tune after physical calibration |

### Step-by-step procedure

**What you need:** multimeter, calibrated reference thermometer, ice bath (0°C), room temperature water (~20°C), boiling water (100°C).

1. **Measure R_fixed with a multimeter** — never use the nominal value. Measure the actual resistance before soldering. Enter this exact value in the **R-Fixed (Ω)** field in Settings.

2. **Measure NTC resistance at 3 known temperatures:**
   - Ice bath → 0°C
   - Room temperature → ~20°C
   - Boiling water → ~100°C
   
   At each temperature, measure NTC resistance with a multimeter.

3. **Enter the 3 data points into the SRS NTC Calculator:**
   🔗 [https://www.thinksrs.com/downloads/programs/therm%20calc/ntccalibrator/ntccalculator.html](https://www.thinksrs.com/downloads/programs/therm%20calc/ntccalibrator/ntccalculator.html)

   Example inputs:
   - T1 = 0°C, R1 = 27,280 Ω
   - T2 = 20°C, R2 = 12,090 Ω
   - T3 = 100°C, R3 = 973 Ω

4. **Click Calculate** — the tool outputs A, B, C coefficients.

5. **Enter all values in Settings tab → NTC1-RIMS / NTC2-MASH calibration cards.** Takes effect within 1 second.

6. **Verify** against a reference thermometer. Use the **Offset (°C)** field for single-point fine-tuning.

> **Tip:** The wider the temperature spread, the more accurate the coefficients. Ice bath + boiling water covers the full brewing range.

### Safety guards

The firmware returns `unavailable` when:
- Sensor is disconnected (voltage ≤ 0.7V or ≥ V-ref)
- Calculated temperature is outside 0°C to 100°C

---

## DS18B20 — Offset Correction

> 🔗 See also: [DS18B20 — hardware/ds18b20.md](ds18b20.md)

DS18B20 sensors are factory-calibrated and typically accurate to ±0.5°C. A single-point offset correction is usually sufficient for brewing precision.

### Step-by-step procedure

**What you need:** calibrated reference thermometer, stable temperature bath.

1. Place DS18B20 and reference thermometer in the same stable temperature bath
2. Wait 2–3 minutes for temperature to stabilise
3. Note the DS18B20 reading from the HA dashboard
4. Calculate: `Offset = Reference − DS18B20 reading`
   - Example: reference reads 65.0°C, DS18B20 reads 65.8°C → Offset = **−0.8°C**
5. Enter the Offset in **Settings tab → DS18B20 Offsets** — takes effect within 1 second

### Notes
- Recalibrate if you replace a sensor — each has unique factory calibration
- Calibrate at your typical mash temperature (55–75°C) for best accuracy in that range
- The EMA filter (α=0.25) smooths readings — allow ~5 seconds to stabilise after inserting sensor
- Offset is applied on the ESP32 — HA always receives the corrected value

---

## ADS1115 — Input Verification

> 🔗 See also: [Expansion Boards — hardware/expansion_boards.md](expansion_boards.md)

The ADS1115 requires verification before enabling PID control.

### Floating input safety check

When an ADS1115 input has nothing connected it floats to an indeterminate voltage. Behaviour varies by board batch:

| Behaviour | HA shows | Safety |
|---|---|---|
| Input floats **negative** | `unavailable` | ✅ Safe — correctly indicates disconnected sensor |
| Input floats **positive** (~0.5–1.5V) | False temperature (~60°C) | ❌ Dangerous — PID would react to fake reading |

The firmware uses a 0.7V minimum voltage guard to reject most floating cases, but this is not reliable across all board variants.

**Before enabling PID control, verify:**
1. Disconnect the NTC from ADS1115 A0
2. Check `sensor.singularity_ntc1_rims` in HA — must show `unavailable`
3. If it shows a temperature value, the board drifts positive — do not use it for PID until the NTC is connected

### PGA gain

Gain is set to `6.144` (±6.144V range) even though the signal is 0–3.3V. This maximises resolution for the voltage divider output without risking saturation.

---

## SM6004 + 4-20mA Converter — ZERO/SPAN Calibration

> 🔗 See also: [SM6004 — hardware/sm6004.md](sm6004.md) | [Current to Voltage Converter — hardware/current_to_voltage.md](current_to_voltage.md)

The 4-20mA to 0-3.3V converter module has two trimmer pots — ZERO and SPAN — that must be calibrated once before use.

### One-time calibration procedure

**What you need:** 4-20mA current source or the SM6004 at known flow states.

1. Power up the module — D2 LED should light (confirms power)
2. **At minimum flow (4mA):** turn the **ZERO** pot until `VOUT = 0.0V`
3. **At maximum flow (20mA):** turn the **SPAN** pot until `VOUT = 3.3V`

This maps the 4-20mA range to exactly 0–3.3V for the ADS1115 input.

### Flow conversion formula

Once the converter is calibrated, flow (L/min) is calculated from voltage:

```
Flow (L/min) = (voltage / 3.3) × 25
```

As a Jinja2 template (planned):
```yaml
{% set v = states('sensor.singularity_flow1_raw') | float(0) %}
{{ ((v / 3.3) * 25) | round(2) }}
```

---

## PID Tuning — RIMS Heater

> 🔗 See also: firmware `esp32_singularity.yaml` — PID parameters in Settings tab

The PID controller runs on the ESP32 with parameters configurable from the Settings tab.

### Current defaults (your proven mash values)

| Parameter | Value | Notes |
|---|---|---|
| Kp | 10.0 | Proportional gain |
| Ki | 0.2 | Integral gain (adjusted for 2s loop time) |
| Kd | 5.0 | Derivative gain |
| Max Duty | 100% | Maximum heater output |
| Setpoint | 66.0°C | Target temperature |

> **Note:** Ki was adjusted from your original Ki=0.4 (1s loop) to Ki=0.2 (2s loop) because the singularity PID runs every 2 seconds. Kp and Kd are unchanged.

### Tuning guide

Start with the defaults above. After your first brew, fine-tune based on observed behaviour:

| Symptom | Adjustment |
|---|---|
| Overshoots setpoint | Reduce Kp |
| Holds slightly below setpoint | Increase Ki |
| Oscillates around setpoint | Reduce Ki, increase Kd |
| Too slow to reach setpoint | Increase Kp |
| Scorching risk | Reduce Max Duty (e.g. 80%) |

### Strike water heat-up

For fast heat-up to strike temperature where precision is less critical:

| Parameter | Suggested |
|---|---|
| Kp | 10 |
| Ki | 0 |
| Kd | 0 |
| Max Duty | 80% |

High Kp with zero Ki/Kd saturates output to Max Duty when far from setpoint, then tapers naturally on approach — no overshoot, no scorching.
