# NTC Thermistors

NTC (Negative Temperature Coefficient) thermistors measure temperature via resistance change. singularity uses two NTC sensors read through the ADS1115 ADC.

---

## Sensors

| Sensor | Location | ADS1115 Channel | Entity |
|---|---|---|---|
| NTC1-RIMS | RIMS outlet | A0 (ADC_Port_0) | `sensor.ntc1_rims` |
| NTC2-MASH | Mash tun | A1 (ADC_Port_1) | `sensor.ntc2_mash` |

---

## Wiring — Voltage Divider Circuit

Each NTC is wired as a voltage divider with a fixed resistor. The junction voltage is read by the ADS1115 and converted to temperature using the Steinhart-Hart equation in HA.

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

1. **Measure R at 3 known temperatures** — use an ice bath (0°C), room temp (~20°C), and boiling water (100°C) as reference points. Measure the NTC resistance at each temperature with a multimeter.

2. **Enter the 3 data points** into the calculator:
   - T1, R1 (e.g. 0°C = 27,280Ω)
   - T2, R2 (e.g. 20°C = 12,090Ω)
   - T3, R3 (e.g. 100°C = 973Ω)

3. **Click Calculate** — the tool outputs A, B, C coefficients.

4. **Enter the coefficients** into the Settings tab on the singularity dashboard — no reflash needed.

5. **Verify** — measure temperature at a known reference point and compare against the displayed corrected value. Adjust the offset if needed.

> **Tip:** The more spread out your calibration points are, the more accurate the coefficients. Ice bath + boiling water gives the best range for brewing temperatures.

### Safety Checks

The template sensor returns `none` (unavailable) when:
- Sensor is disconnected (voltage = 0 or ≥ V-ref)
- Calculated temperature is outside −10°C to 150°C range

This prevents garbage readings from being recorded when sensors are disconnected between brew sessions.

---

## ESP32 Firmware Notes

- Raw ADC voltage is sent as `sensor.singularity_ntc1_rims_raw` (unit: V)
- EMA filter (α=0.25) applied in firmware for noise reduction
- Delta filter (0.1V) — only sends update when voltage changes by >0.1V
- All S-H conversion happens in HA template sensors — no hardcoded values in firmware

---

## Cable Recommendations

- Use twisted pair cable for runs longer than 30cm
- Keep cable away from mains wiring and SSR outputs
- Maximum recommended cable length: 2m (beyond this consider shielded cable)
