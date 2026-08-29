# Expansion Boards

All expansion boards communicate over the I2C bus on GPIO 21 (SDA) and GPIO 47 (SCL).

## Boards

- [I2C Bus — General Rules](#i2c-bus--general-rules)
- [ADS1115 — 16-bit ADC](#ads1115--16-bit-adc)
- [MCP4728 — 12-bit Quad DAC](#mcp4728--12-bit-quad-dac)
- [MCP23017 — 16-bit GPIO Expander](#mcp23017--16-bit-gpio-expander)

---

## I2C Bus — General Rules

### Pull-up Resistors

The I2C bus requires pull-up resistors between SDA/SCL and 3.3V:

```
3.3V ──── 4.7kΩ ──── GPIO 21 (SDA)
3.3V ──── 4.7kΩ ──── GPIO 47 (SCL)
```

**Important:** Most breakout modules already include onboard pull-ups. To verify:
- Power the module alone
- Measure SDA and SCL vs GND with a multimeter
- If ~3.3V → onboard pull-ups present, no external resistors needed
- If 0V → add 4.7kΩ external pull-ups

**Do not stack pull-ups:** If multiple modules each have onboard pull-ups, the resistors are in parallel which lowers the effective value (e.g. 3 × 4.7kΩ = 1.57kΩ — too low). Remove pull-ups from all but one module if stacking.

### Speed

Default I2C speed in ESPHome is 50kHz. For better performance use 400kHz:
```yaml
i2c:
  sda: GPIO21
  scl: GPIO47
  frequency: 400kHz
```

If signal quality issues occur with long wires, drop back to 100kHz.

### Address Map

| Address | Device | Status |
|---|---|---|
| `0x20` | MCP23017 #1 | Planned |
| `0x48` | ADS1115 #1 | Active — NTC1 (A0), NTC2 (A1), FLOW1 (A2), FLOW2 (A3) |
| `0x49` | ADS1115 #2 | On hold — all channels on #1 (0x48); floating input issue on #2 (see README for details) |
| `0x60` | MCP4728 #1 | Planned |
| `0x61` | MCP4728 #2 | Planned (address reprogrammed) |

---

## ADS1115 — 16-bit ADC

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ADS1115.jpg" width="50%"/>

> 🔗 [Texas Instruments ADS1115 Product Page](https://www.ti.com/product/ADS1115) | [Adafruit Breakout Guide](https://learn.adafruit.com/adafruit-4-channel-adc-breakouts)

### Technical Specifications

| Parameter | Value |
|---|---|
| **Resolution** | 16-bit |
| **Architecture** | Delta-Sigma |
| **Channels** | 4 single-ended or 2 differential |
| **Sample rate** | 8–860 SPS (programmable) |
| **PGA input range** | ±0.256V to ±6.144V (6 settings) |
| **Interface** | I2C |
| **I2C addresses** | 0x48–0x4B (set via ADDR pin) |
| **Supply voltage** | 2.0–5.5V |
| **Current consumption** | 150µA continuous, 2µA power-down |
| **Onboard reference** | Yes (internal) |
| **Comparator** | Yes (programmable) |
| **Package** | Breakout board |

### Address Configuration

| ADDR pin | I2C Address |
|---|---|
| GND | 0x48 |
| VDD | 0x49 |
| SDA | 0x4A |
| SCL | 0x4B |

Used for [NTC](ntc.md) thermistors and flow meter analog inputs (via [4-20mA converter modules](current_to_voltage.md)).

| Parameter | Value |
|---|---|
| Address | 0x48 (ADDR → GND) — active |
| Channels | 4 single-ended (A0–A3) |
| Resolution | 16-bit |
| Input range | ±6.144V (gain 1) |
| Supply | 3.3V |

**Pin assignments:**

| ADS1115 Pin | ESP32 |
|---|---|
| VDD | 3.3V |
| GND | GND |
| SDA | GPIO 21 |
| SCL | GPIO 47 |
| ADDR | GND → 0x48 (only one board used) |

**Port mapping:**

| Logical Port | Physical | ADS1115 | Use |
|---|---|---|---|
| ADC_Port_0 | A0 | #1 (0x48) | NTC1-RIMS |
| ADC_Port_1 | A1 | #1 (0x48) | NTC2-MASH |
| ADC_Port_2 | A2 | #1 (0x48) | [SM6004](sm6004.md) FLOW1 (planned) |
| ADC_Port_3 | A3 | #1 (0x48) | [SM6004](sm6004.md) FLOW2 (planned) |

### Calibration and safety verification

> 📖 Full details → **[hardware/calibration.md](calibration.md#ads1115--input-verification)**

Always verify that disconnected sensor inputs show `unavailable` in HA before enabling PID control. Some board batches float positive when disconnected, producing false temperature readings.

---

## MCP4728 — 12-bit Quad DAC

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/MCP4728-1.jpg" width="50%"/>

> 🔗 [AliExpress — MCP4728 I2C DAC Module](https://de.aliexpress.com/item/1005012505445193.html) | [Microchip Datasheet](https://www.mouser.com/datasheet/2/268/22187E-12972.pdf)

### Technical Specifications

| Parameter | Value |
|---|---|
| **Chip** | Microchip MCP4728 |
| **Resolution** | 12-bit |
| **Channels** | 4 (A, B, C, D) |
| **Output voltage range** | 0 to VDD (external ref) or 0–2.048V / 0–4.096V (internal ref) |
| **Internal reference** | 2.048V (×1 or ×2 gain) |
| **Settling time** | 6 µs (typical) |
| **Interface** | I2C (100kbps / 400kbps / 3.4Mbps) |
| **Default I2C address** | 0x60 |
| **Supply voltage** | 2.7–5.5V |
| **EEPROM** | Yes — stores DAC values and I2C address |
| **Temperature range** | −40°C to +125°C |

### I2C Address Configuration

The MCP4728 address is stored in internal EEPROM — **cannot be changed with resistors or jumpers**. Must be programmed via I2C command using Arduino IDE before installing two units on the same bus.

| A2 | A1 | A0 | I2C Address |
|---|---|---|---|
| 0 | 0 | 0 | **0x60** (default) |
| 0 | 0 | 1 | 0x61 |
| 0 | 1 | 0 | 0x62 |
| 0 | 1 | 1 | 0x63 |
| 1 | 0 | 0 | 0x64 |
| 1 | 0 | 1 | 0x65 |
| 1 | 1 | 0 | 0x66 |
| 1 | 1 | 1 | 0x67 |

> **Note:** Some boards (Adafruit after Aug 2022) may ship at 0x64. Scan I2C bus first to confirm actual address. See main README for reprogramming procedure.

**Port mapping:**

| Logical Port | Physical | MCP4728 | Use |
|---|---|---|---|
| DAC_Port_0 | A | #1 (0x60) | Proportional valve (planned) |
| DAC_Port_1 | B | #1 (0x60) | Spare |
| DAC_Port_2 | C | #1 (0x60) | Spare |
| DAC_Port_3 | D | #1 (0x60) | Spare |
| DAC_Port_4 | A | #2 (0x61) | Spare |
| DAC_Port_5 | B | #2 (0x61) | Spare |
| DAC_Port_6 | C | #2 (0x61) | Spare |
| DAC_Port_7 | D | #2 (0x61) | Spare |

---

## MCP23017 — 16-bit GPIO Expander

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/MCP23017-1.png" width="50%"/>

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/MCP23017-2.jpg" width="50%"/>

Adds 16 additional GPIO pins via I2C. Planned for relay outputs, button inputs, LED indicators.

| Parameter | Value |
|---|---|
| Address | 0x20–0x27 (set via A0/A1/A2 pins) |
| Pins | 16 (Port A: 8, Port B: 8) |
| Each pin | Configurable as input or output |
| Interrupt | Yes — can alert ESP32 on input change |
| Supply | 3.3V or 5V (signal level must match ESP32 = 3.3V) |

**No address conflicts** with existing devices — `0x20` is free.

---

## General Wiring Notes

- All I2C devices share the same two wires (SDA, SCL) plus power and ground
- Connect all GNDs together ([ESP32](esp32.md), all modules, power supply)
- Use short wires between modules where possible — each cm adds capacitance
- For enclosure builds: route I2C wiring away from SSR and mains wiring
