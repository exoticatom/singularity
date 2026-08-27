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
| `0x48` | ADS1115 #1 | Active |
| `0x49` | ADS1115 #2 | Planned |
| `0x60` | MCP4728 #1 | Planned |
| `0x61` | MCP4728 #2 | Planned (address reprogrammed) |

---

## ADS1115 — 16-bit ADC

![ADS1115 module](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ADS1115.jpg)

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

Used for NTC thermistors and flow meter analog inputs (via 4-20mA converter modules).

| Parameter | Value |
|---|---|
| Address | 0x48 (ADDR → GND), 0x49 (ADDR → VCC) |
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
| ADDR | GND = 0x48, VCC = 0x49 |

**Port mapping:**

| Logical Port | Physical | ADS1115 | Use |
|---|---|---|---|
| ADC_Port_0 | A0 | #1 (0x48) | NTC1-RIMS |
| ADC_Port_1 | A1 | #1 (0x48) | NTC2-MASH |
| ADC_Port_2 | A2 | #1 (0x48) | Spare |
| ADC_Port_3 | A3 | #1 (0x48) | Spare |
| ADC_Port_4 | A0 | #2 (0x49) | FLOW1 (planned) |
| ADC_Port_5 | A1 | #2 (0x49) | FLOW2 (planned) |
| ADC_Port_6 | A2 | #2 (0x49) | Spare |
| ADC_Port_7 | A3 | #2 (0x49) | Spare |

---

## MCP4728 — 12-bit Quad DAC

Used for analog outputs (proportional valve control, future expansion).

| Parameter | Value |
|---|---|
| Default address | 0x60 (ADDR pins → GND) |
| Channels | 4 (A, B, C, D) |
| Output range | 0–3.3V |
| Resolution | 12-bit |
| Supply | 3.3V |

**Address reprogramming (for second MCP4728):**
The MCP4728 address is stored in internal EEPROM and cannot be changed with resistors. Use Arduino IDE to send the `MCP4728_CMD_WRITE_I2C_ADDRESS` command to change `0x60` → `0x61` before installing both on the same bus. See main README for procedure.

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

![MCP23017 IO Expansion Board](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/MCP23017-1.png)

![MCP23017 pinout](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/MCP23017-2.jpg)

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
- Connect all GNDs together (ESP32, all modules, power supply)
- Use short wires between modules where possible — each cm adds capacitance
- For enclosure builds: route I2C wiring away from SSR and mains wiring
