# singularity — Hardware Documentation

This folder contains all hardware-related documentation for the singularity brewing controller.

---

## Contents

| Page | Description |
|---|---|
| 🔧 [ESP32-S3-DEV-KIT-NXRX](esp32.md) | Board overview, pinout diagrams, wiring summary |
| 🔌 [ESP32-S3 Expansion Board](esp32_expansion_board.md) | Screw terminal breakout adapter for all 44 pins |
| 📌 [GPIO Map](gpio_map.md) | ESP32-S3 pin rules, bus assignments, reserved pins, sensor pin map |
| 🌡️ [NTC Thermistors](ntc.md) | Wiring, voltage divider circuit, Steinhart-Hart calibration |
| 🌡️ [DS18B20](ds18b20.md) | 1-Wire digital temperature sensor — wiring and ROM address discovery |
| 🔲 [Expansion Boards](expansion_boards.md) | I2C boards (ADS1115, MCP4728, MCP23017), pull-up rules, address map |
| ⚡ [Current to Voltage Module](current_to_voltage.md) | 4-20mA → 0-3.3V converter for SM6004 and other industrial sensors |
| 💧 [SM6004 Flow Sensor](sm6004.md) | IFM magnetic-inductive flow meter — 4-20mA wiring via converter module |
| 💧 [YF-S200 Flow Sensor](yf_s200.md) | Hall effect pulse flow sensor — 5V supply, GPIO wiring options |

---

## General Notes

### 3.3V Logic — Critical Rule

The ESP32-S3 operates at **3.3V logic**. All sensors and modules must be compatible with 3.3V signal levels. Never connect 5V logic signals directly to ESP32 GPIO pins.

### I2C Bus Pull-ups

The I2C bus (SDA = GPIO 21, SCL = GPIO 47) requires pull-up resistors to 3.3V. Most breakout modules include onboard pull-ups. See [Expansion Boards](expansion_boards.md) for details.

### Power Supply Isolation

The SM6004 and proportional valve operate at 24V DC. The ESP32 and all sensors operate at 3.3V. Keep 24V wiring separated from the low-voltage signal wiring. Use dedicated 4-20mA converter modules for signal level translation.

### Connector Recommendation

Use screw terminals or JST connectors for all sensor connections. Label all wires at both ends. Twisted pair cable for runs longer than 30cm.
