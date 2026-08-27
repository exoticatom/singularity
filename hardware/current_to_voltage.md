# Current to Voltage Converter Module

> 🔗 [AliExpress — Current To Voltage Module 0/4-20mA to 0-3.3V/0-5V/0-10V](https://de.aliexpress.com/item/1005003402577144.html)

Used to convert the 4-20mA analog outputs of industrial sensors (SM6004 flow meter) to a 0-3.3V voltage signal readable by the ADS1115 ADC.

![Current to Voltage Converter Module](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ConvertorModule.jpg)

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

## Calibration for SM6004 Flow Meter

The SM6004 outputs **4mA at minimum flow** (0.1 L/min) and **20mA at maximum flow** (25 L/min). The converter module must be calibrated to map this range exactly to 0–3.3V.

### What you need
- Multimeter (DC voltage mode)
- SM6004 powered and connected
- Converter module powered (D2 LED on)

### Step 1 — Set jumpers
Both J1 jumpers **OPEN** → 4-20mA → 0-3.3V mode.

### Step 2 — Calibrate ZERO (4mA = 0V)

The SM6004 outputs 4mA when flow is at minimum or zero. To simulate this:

**Option A — No flow (easiest)**
Block or close the pipe so there is zero flow through the SM6004. The sensor outputs 4mA idle current.

**Option B — SM6004 parameter setting**
In the SM6004 menu set `ASP2` (Analogue Start Point for OUT2) — this is the 4mA point, default = 0.1 L/min.

With 4mA on the input:
- Measure VOUT with multimeter
- Turn **ZERO** potentiometer until VOUT = **0.00V**

### Step 3 — Calibrate SPAN (20mA = 3.3V)

The SM6004 outputs 20mA at full scale flow (default 25 L/min = `AEP2`).

**Option A — Run maximum flow**
Open the valve fully and run 25 L/min through the sensor.

**Option B — SM6004 parameter setting**
Temporarily set `AEP2` to a low value you can achieve, note the actual mA output, then calculate.

**Option C — Use a 20mA current source** (most accurate)
If you have a current calibrator or source set to exactly 20mA, inject it directly into IN+ / IN−. Then turn **SPAN** potentiometer until VOUT = **3.30V**.

### Step 4 — Verify
Check both endpoints:
- 4mA input → VOUT should be ~0.00V
- 20mA input → VOUT should be ~3.30V

### Step 5 — Lock down
Once calibrated do not touch the pots again. If the SM6004 is replaced or the 4-20mA range is rescaled in the SM6004 menu, recalibrate.

### Expected readings in HA after calibration

| SM6004 OUT2 | Converter VOUT | `sensor.singularity_flow1_raw` | Flow |
|---|---|---|---|
| 4mA (min) | 0.0V | ~0.0 | 0 L/min |
| 12mA (mid) | 1.65V | ~1.65 | ~12.5 L/min |
| 20mA (max) | 3.3V | ~3.3 | 25 L/min |

HA template formula: `Flow = (voltage / 3.3) × 25`

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
| SM6004 #1 — Flow (OUT2) | ADC_Port_4 (ADS1115 #2, A0) |
| SM6004 #1 — Temp (OUT1) | ADC_Port_5 (ADS1115 #2, A1) |
| SM6004 #2 — Flow (OUT2) | ADC_Port_6 (ADS1115 #2, A2) |

One module required per sensor output channel.

---

## Status

Planned — pending ADS1115 #2 installation.
