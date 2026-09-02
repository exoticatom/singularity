# Current to Voltage Converter Module

> 🔗 [AliExpress — Current To Voltage Module 0/4-20mA to 0-3.3V/0-5V/0-10V](https://de.aliexpress.com/item/1005003402577144.html)

Used to convert the 4-20mA analog outputs of industrial sensors ([SM6004](sm6004.md) flow meter) to a 0-3.3V voltage signal readable by the [ADS1115](expansion_boards.md) ADC.

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ConvertorModule.jpg" width="50%"/>

---

## Technical Specifications

| Parameter | Value |
|---|---|
| **Input current range** | 0–20mA or 4–20mA (selectable) |
| **Output voltage range** | 0–3.3V / 0–5V / 0–10V (selectable via jumper) |
| **Supply voltage** | 7–36V DC (if output ≤5V) / must be >12V for 0–10V output |
| **Accuracy** | High precision, good linearity |
| **Operating temperature** | −45°C to +85°C |
| **Zero adjustment** | ZERO potentiometer |
| **Span adjustment** | SPAN potentiometer |
| **Power indicator** | D2 LED (lights when powered) |
| **Reverse polarity protection** | Yes |

---

## Output Range Selection — Jumper Settings (J1)

| Mode | J1 pins 1-2 | J1 pins 3-4 | Output |
|---|---|---|---|
| **4-20mA → 0-3.3V** | OPEN | OPEN | 0–3.3V ✅ used in singularity |
| 4-20mA → 0-2.5V | SHORT | SHORT | 0–2.5V |
| 4-20mA → 0-5V | SHORT | SHORT | 0–5V |
| 4-20mA → 0-10V | SHORT | OPEN | 0–10V |
| 0-20mA → 0-3.3V | SHORT | SHORT | 0–3.3V |
| 0-20mA → 0-5V | SHORT | SHORT | 0–5V |
| 0-20mA → 0-10V | SHORT | OPEN | 0–10V |

> **For singularity:** Set both J1 jumpers to **OPEN** for 4-20mA → 0-3.3V mode.

---

## Terminal Connections

| Terminal | Connect to |
|---|---|
| `VIN+` | 24V PSU positive |
| `VIN−` | 24V PSU GND (common ground) |
| `IN+` | Sensor signal output (e.g. SM6004 OUT2) |
| `IN−` | 24V PSU GND |
| `VOUT` | ADS1115 input channel |
| `GND` | ESP32 / ADS1115 GND |

---

## Calibration for [SM6004](sm6004.md) Flow Meter

> 📖 Full step-by-step procedure → **[hardware/calibration.md](calibration.md#sm6004--4-20ma-converter--zerospan-calibration)**

You do **not** need a current source, and you do **not** need to reach 25 L/min. The 4-20mA curve is linear — two real-world points are sufficient.

### Step 1 — ZERO (pump off)
- Stop pump completely (zero flow)
- Measure VOUT with multimeter
- Turn **ZERO** pot until VOUT = **0.00V**

### Step 2 — SPAN (maximum achievable flow)
- Run pump at your maximum achievable flow
- Read L/min value off the **SM6004 display** (no need to measure current)
- Measure VOUT with multimeter at the same time
- Calculate expected voltage: `(L/min ÷ 25) × 3.3`
- Turn **SPAN** pot until VOUT matches that calculated value

### Calibration values (this installation)

| Point | SM6004 display | VOUT set to | Notes |
|---|---|---|---|
| Zero flow | 0.0 L/min | 0.000 V | ZERO pot |
| Max achievable | 13.20 L/min | 1.743 V | (13.20/25)×3.3 |

**Slope:** `7.57 L/min per volt`

### Step 3 — Fine-tune offset from dashboard

Once connected to ADS1115, compare SM6004 display vs HA reading at steady flow. Adjust `number.singularity_flow1_offset` in the Settings tab — same pattern as DS18B20 offsets. No re-wiring, no pot adjustment needed.

### Expected readings after calibration

| SM6004 display | Converter VOUT | ADS1115 reading | Flow (slope×V) |
|---|---|---|---|
| 0.0 L/min | 0.000 V | ~0.000 | 0.0 L/min |
| 13.20 L/min | 1.743 V | ~1.743 | 13.2 L/min |
| 25.0 L/min | 3.300 V | ~3.300 | 25.0 L/min |

---

## Common Ground — Critical

All GNDs must be connected together:

```
24V PSU GND ──── Module VIN− / IN−
                       │
                       └──── ESP32 GND ──── ADS1115 GND
```

Without common ground the current loop has no return path and readings will be incorrect.

---

## Usage in singularity

| Sensor | Module output → ADS1115 channel |
|---|---|
| SM6004 #1 — Flow (OUT2) | ADS1115 #1 (0x48) A2 |
| SM6004 #1 — Temp (OUT1) | ADS1115 #1 (0x48) A3 |

One module required per sensor output channel.

---

## Status

Connected and calibrated — ZERO/SPAN set. ESPHome config pending (ADS1115 A2/A3).
