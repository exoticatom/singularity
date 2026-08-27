# NTC Thermistors

NTC (Negative Temperature Coefficient) thermistors measure temperature via resistance change. singularity uses two NTC sensors read through the ADS1115 ADC.

---

## Sensors

| Sensor | Location | ADS1115 Channel | Entity |
|---|---|---|---|
| NTC1-RIMS | RIMS outlet | A0 (ADC_Port_0) | `sensor.ntc1_rims` |
| NTC2-MASH | Mash tun | A1 (ADC_Port_1) | `sensor.ntc2_mash` |

### Sensor Used in This Installation

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/NTC_Sensor.jpg" width="50%"/>

**Kabelfühler — Durchmesser Ø5mm** — Made in Germany

| Parameter | Value |
|---|---|
| Article number | KP-NTC10k-2L-2.0-560-W |
| Sensor type | NTC 10kΩ |
| Cable material | PVC (also available in Silikon) |
| Cable length | 2m (2-wire) |
| Probe diameter | Ø5mm |
| Probe length | 60mm |
| Waterproof | Yes (IP67 optional) |
| Max temperature | 180°C |

**Where to order:**
- 🔗 [sensorshop24.de — Kabelfühler Ø5mm](https://www.sensorshop24.de/temperaturfuehler-passiv/kabelfuehler-durchmesser-5mm) — currently available
- The previously ordered article (`KP-NTC10k-2L-2.0-560-W`) is no longer listed but equivalent sensors are available

**Probe diameter options:** 4mm, 5mm, 6mm etc — all electrically identical, choice depends on physical installation requirements.

> If sourcing a replacement, look for any NTC 10kΩ cable probe (Kabelfühler) with similar dimensions. Recalibrate A, B, C coefficients for the new sensor using the SRS calculator.

---

## Wiring — Voltage Divider Circuit

Each NTC is wired as a voltage divider with a fixed resistor. The junction voltage is read by the ADS1115 and converted to temperature using the Steinhart-Hart equation **in ESP32 firmware**.

```
3.3V
 │
 R_fixed (measured, ~10kΩ)
 │
 ├──────────────────── ADS1115 Ax input
 │                           │
 │                         100nF (HF filter cap)
 │                           │
 NTC thermistor              GND
 │
GND
```

**Both channels on ADS1115 #1:**

```
          3.3V
           │
     ┌─────┴─────┐
     │           │
  R1(10kΩ)    R2(10kΩ)
     │           │
     ├─C1(100nF)─┤─C2(100nF)─GND
     │           │
  ADS1115 A0  ADS1115 A1
     │           │
   NTC1        NTC2
  (RIMS)      (MASH)
     │           │
     └─────┬─────┘
          GND
```

### ADS1115 Connections

| ADS1115 Pin | Connect to |
|---|---|
| VDD | 3.3V |
| GND | GND |
| SDA | ESP32 GPIO 21 |
| SCL | ESP32 GPIO 47 |
| ADDR | GND (sets address 0x48) |
| A0 | NTC1 junction + 100nF to GND |
| A1 | NTC2 junction + 100nF to GND |

### Component Values

| Component | Value | Notes |
|---|---|---|
| R_fixed | ~10kΩ (measure actual value) | 1% tolerance recommended |
| NTC | 10kΩ @ 25°C | Match to your sensor spec |
| C_filter | 100nF ceramic | Between junction and GND |

> **Important:** Measure the actual resistance of R_fixed with a multimeter and enter the exact value in the calibration settings. This improves accuracy significantly.

---

## Calibration — Steinhart-Hart Equation

singularity uses the full 3-coefficient Steinhart-Hart equation for accurate temperature conversion across a wide range:

```
1/T = A + B·ln(R) + C·(ln(R))³
T(°C) = (1/T_kelvin) - 273.15 + offset
```

Where:
- `R` = NTC resistance = `r_fixed × V / (v_ref − V)`
- `V` = raw ADC voltage from ESP32
- `T` = temperature in Kelvin

### Calibration Values (configurable from Settings tab)

| Parameter | NTC1-RIMS | NTC2-MASH | Notes |
|---|---|---|---|
| R-Fixed (Ω) | 9883 | 9902 | Measured actual resistor value |
| V-Ref (V) | 3.3 | 3.3 | ESP32 supply voltage |
| A | 0.001207071588 | 0.001209771862 | Steinhart-Hart coefficient |
| B | 0.0002183328996 | 0.0002173461562 | Steinhart-Hart coefficient |
| C | 0.0000001764463641 | 0.0000001848376283 | Steinhart-Hart coefficient |
| Offset (°C) | 0.0 | 0.0 | Fine-tune after physical calibration |

### How to Get Your S-H Coefficients

The best way is to use the **SRS NTC Thermistor Calculator**:

🔗 [https://www.thinksrs.com/downloads/programs/therm%20calc/ntccalibrator/ntccalculator.html](https://www.thinksrs.com/downloads/programs/therm%20calc/ntccalibrator/ntccalculator.html)

**Step-by-step procedure:**

1. **Measure your fixed resistor (R_fixed) with a multimeter**
   This is critical — never use the nominal value. Measure the actual resistance of the fixed resistor before soldering it in. Enter this exact value in the **R-Fixed (Ω)** field in the Settings tab.

2. **Measure NTC resistance at 3 known temperatures**
   Use an ice bath (0°C), room temperature (~20°C), and boiling water (100°C) as reference points. Measure the NTC resistance at each temperature with a multimeter.

3. **Enter the 3 data points** into the SRS calculator:
   - T1, R1 (e.g. 0°C = 27,280Ω)
   - T2, R2 (e.g. 20°C = 12,090Ω)
   - T3, R3 (e.g. 100°C = 973Ω)

4. **Click Calculate** — the tool outputs A, B, C coefficients.

5. **Enter all values into the singularity dashboard → Settings tab:**

   The Settings tab shows the calibration card for each NTC:

   ```
   NTC1-RIMS — Steinhart-Hart Calibration
   R = r_fixed × V / (v_ref − V) → 1/T = A + B·ln(R) + C·ln(R)³

   R-Fixed (Ω)    → measured resistor value (e.g. 9883)
   V-Ref (V)      → 3.3
   Coefficient A  → from calculator (e.g. 0.001207071588)
   Coefficient B  → from calculator (e.g. 0.0002183328996)
   Coefficient C  → from calculator (e.g. 1.764463641e-7)
   ```

   Values are written to the ESP32 via `number` entities and **persisted to ESP32 flash**. The controller continues using last known values even if HA is offline.

6. **Verify** by comparing the displayed corrected temperature against a reference thermometer. Fine-tune using the **Offset (°C)** field if needed.

> **Tip:** The more spread out your calibration points are, the more accurate the coefficients. Ice bath + boiling water gives the best range for brewing temperatures.

### Safety Checks

The template sensor returns `none` (unavailable) when:
- Sensor is disconnected (voltage = 0 or ≥ V-ref)
- Calculated temperature is outside −10°C to 150°C range

This prevents garbage readings from being recorded when sensors are disconnected between brew sessions.

---

## ESP32 Firmware Notes

As of v2.0.0, the full Steinhart-Hart calculation runs directly on the ESP32:

- Raw ADC voltage is read from ADS1115 and processed entirely in firmware
- S-H parameters are stored as `number` entities with `restore_value: true` — they persist to ESP32 flash and survive reboots
- EMA filter (α=0.25) is baked in — applied after S-H conversion
- Returns `NAN` (unavailable) if sensor is disconnected or temperature is outside −10°C to 150°C
- Published entity: `sensor.singularity_ntc1_rims` and `sensor.singularity_ntc2_mash` — corrected °C directly

---

## Database Management

NTC sensors update every 1 second. The EMA filter smooths the output so only meaningful changes are published. Out-of-range values (disconnected sensor) return `NAN` which HA does not record — so disconnected sensors between brew sessions don't pollute the database.

The recorder excludes for `_RAW` entities are no longer needed since there are no raw NTC entities.

---

## Cable Recommendations

- Use twisted pair cable for runs longer than 30cm
- Keep cable away from mains wiring and SSR outputs
- Maximum recommended cable length: 2m (beyond this consider shielded cable)
