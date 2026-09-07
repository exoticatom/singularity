# singularity — Hardware Documentation

This folder contains all hardware-related documentation for the singularity brewing controller.

---

## Contents

| Page | Description |
|---|---|
| 🔧 [ESP32-S3 Boards](esp32.md) | Board overview, pinout diagrams, wiring summary (Board 1 Waveshare + Board 2 44-pin, active) |
| 🔌 [ESP32-S3 Expansion Board](esp32_expansion_board.md) | Screw terminal breakout adapter for all 44 pins |
| 📌 [GPIO Map](gpio_map.md) | ESP32-S3 pin rules, bus assignments, reserved pins, sensor pin map |
| 🖥️ [Display & Kiosk](display_kiosk.md) | Joy-IT RB-LCD10-2 10.1" touchscreen + Raspberry Pi 4 kiosk setup |
| 🌡️ [NTC Thermistors](ntc.md) | Wiring, voltage divider circuit, Steinhart-Hart calibration |
| 🌡️ [DS18B20](ds18b20.md) | 1-Wire digital temperature sensor — wiring and ROM address discovery |
| 🔲 [Expansion Boards](expansion_boards.md) | I2C boards (ADS1115, MCP4728, MCP23017), pull-up rules, address map |
| ⚡ [Current to Voltage Module](current_to_voltage.md) | 4-20mA → 0-3.3V converter for SM6004 and other industrial sensors |
| 💧 [SM6004 Flow Sensor](sm6004.md) | IFM magnetic-inductive flow meter — 4-20mA wiring via converter module |
| 💧 [YF-S200 Flow Sensor](yf_s200.md) | Hall effect pulse flow sensor — 5V supply, GPIO wiring options |
| 🧪 [Calibration Guide](calibration.md) | Calibration procedures for NTC, DS18B20, ADS1115, SM6004, PID |

---

## General Notes

### 3.3V Logic — Critical Rule

The ESP32-S3 operates at **3.3V logic**. All sensors and modules must be compatible with 3.3V signal levels. Never connect 5V logic signals directly to ESP32 GPIO pins.

### I2C Bus Pull-ups

The I2C bus (SDA = GPIO 21, SCL = GPIO 47) requires pull-up resistors to 3.3V. Most breakout modules include onboard pull-ups. See [Expansion Boards](expansion_boards.md) for details.

### Power Supply Isolation

The SM6004 and proportional valve operate at 24V DC. The ESP32 and all sensors operate at 3.3V. Keep 24V wiring separated from the low-voltage signal wiring. Use dedicated 4-20mA converter modules for signal level translation.

### GND — Common Ground Point

**All low-voltage GNDs must connect to a single common point:**

- ESP32 GND
- ADS1115 GND
- DS18B20 GND
- NTC voltage divider GND
- 4-20mA converter module GND
- 5V DC-DC converter GND
- SM6004 GND (via converter module)

Connecting GNDs to different points creates **ground loops** — small voltage differences between GND points that appear as noise on analog signals (NTC, flow sensors). This causes unstable readings and can make the ADS1115 produce random spikes.

> **Rule:** One GND wire from each module, all meeting at a single star point on the main terminal block.

### ⚠️ CRITICAL — Never Connect Mains GND to Low-Voltage GND

**The mains earth/ground (PE — Protective Earth) must NEVER be connected to the low-voltage signal GND (ESP32, sensors, ADS1115).**

| Ground type | What it is | Connect to |
|---|---|---|
| Mains PE (earth) | Safety earth — connected to enclosure, mains plug earth pin | Enclosure only |
| Low-voltage GND | 0V reference for ESP32, sensors, 24V PSU return | All low-voltage modules |

Connecting mains PE to signal GND introduces **50/60Hz mains interference** directly into the sensor readings and can permanently damage the ESP32 and ADS1115. It also creates a shock hazard.

The 24V PSU GND (DC negative) is the low-voltage system ground — it is NOT the same as mains PE, even if the PSU shares the same mains plug.

### Connector Recommendation

Use screw terminals or JST connectors for all sensor connections. Label all wires at both ends. Twisted pair cable for runs longer than 30cm.

---

## Display & Kiosk

The brewing controller uses a dedicated touchscreen display running in kiosk mode:

| Component | Details |
|---|---|
| Display | Joy-IT RB-LCD10-2 — 10.1" IPS, 1280×800, HDMI + USB touch, 12V DC |
| Computer | Raspberry Pi 4 (2GB) — Raspberry Pi OS Lite, Chromium kiosk mode |
| Hostname | `singularity-kiosk-wifi` |
| Default page | singularity Home Assistant dashboard |

The Pi 4 and display are physically separate from the main electrical box — connected to the same network via WiFi.

📖 Full setup guide → **[display_kiosk.md](display_kiosk.md)**
📄 Kiosk script → **[scripts/kiosk.sh](scripts/kiosk.sh)**
