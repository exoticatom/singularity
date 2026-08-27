# Current to Voltage Converter Module

> 🔗 [AliExpress — Current To Voltage Module 0/4-20mA to 0-3.3V/0-5V/0-10V](https://de.aliexpress.com/item/1005003402577144.html)

Used to convert the 4-20mA analog outputs of industrial sensors (SM6004 flow meter) to a 0-3.3V voltage signal readable by the ADS1115 ADC.

![Current to Voltage Converter Module](https://ae-pic-a1.aliexpress-media.com/kf/Sf7f167391e064590ac035b9b94c81330J/Current-To-Voltage-Module-0-20mA-4-20mA-to-0-3-3V-0-5V-0-10V.jpg_960x960.jpg)

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

## Calibration (one time)

1. Power up — **D2 LED lights** (confirms power OK)
2. With sensor at **minimum signal (4mA)**:
   - Turn **ZERO** potentiometer until VOUT = **0.0V** (measure with multimeter)
3. With sensor at **maximum signal (20mA)**:
   - Turn **SPAN** potentiometer until VOUT = **3.3V**
4. Done — do not touch again unless sensor is replaced

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
