# ESP32-S3 Expansion Adapter Board

> 🔗 [AliExpress — ESP32-S3 Development Board with Expansion Adapter Kit](https://de.aliexpress.com/item/1005008790807170.html)

The expansion adapter board breaks out all 44 pins of the ESP32-S3-DevKitC-1 to screw terminal connectors, making it much easier to connect sensors, relays and other peripherals without soldering or breadboards.

---

![ESP32 Expansion Board](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-Expansion%20Board.jpg)

![ESP32 Expansion Board pins](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-Expansion%20Board-2.jpg)

![ESP32 Expansion Board detail](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-Expansion%20Board-3.jpg)

![ESP32 Expansion Board overview](https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-Expansion%20Board-4.jpg)

---

## Key Features

| Parameter | Value |
|---|---|
| **Compatible board** | ESP32-S3-DevKitC-1 (44-pin, N16R8) |
| **Connection type** | Screw terminal blocks for all GPIO pins |
| **Power input** | USB Type-C passthrough |
| **Pin access** | All 44 pins broken out |
| **Power rails** | 3.3V and 5V screw terminals |
| **Form factor** | DIN rail or standalone |

---

## Why Use an Expansion Board

- **No soldering** — screw terminals for all connections
- **No breadboard** — direct wire connections
- **Easy rewiring** — swap sensors without desoldering
- **Labelled pins** — GPIO numbers printed on board
- **Robust** — suitable for semi-permanent installations

---

## Singularity Pin Usage

| Screw terminal | GPIO | Connected to |
|---|---|---|
| SDA | GPIO 21 | ADS1115 SDA |
| SCL | GPIO 47 | ADS1115 SCL |
| IO48 | GPIO 48 | DS18B20 1-Wire DQ |
| IO41 | GPIO 41 | SSR1 relay |
| IO42 | GPIO 42 | SSR2 RIMS Heater relay |
| 3V3 | — | ADS1115 VDD, DS18B20 VDD, pull-up resistors |
| GND | — | All sensor GNDs |

---

## Notes

- The ESP32-S3-DevKitC-1 has **2×22 pins** (44 total). Verify the expansion board matches this pin count before ordering — some boards are designed for 38-pin or 40-pin variants.
- The expansion board does not add any functionality — it is purely a breakout/connector aid.
