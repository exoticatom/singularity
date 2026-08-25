# gpio_map.md
#
# Project: singularity
# Purpose: ESP32-S3-WROOM-1 GPIO pin reference and bus assignment map.
#          This file is the single source of truth for all hardware pin
#          decisions. Every pin assignment must be recorded here before
#          it is used in any firmware or configuration file.
#
# Last updated: 2026-08-25

---

## ESP32-S3-WROOM-1 Pin Rules

### ❌ RESERVED — DO NOT USE

| GPIO Range | Reason |
|------------|--------|
| GPIO 26–32 | Internal Flash / PSRAM strapping — connected to module flash; using these will corrupt firmware |
| GPIO 19–20 | USB JTAG D− / D+ lines — required for USB debugging and flashing |
| GPIO 43–44 | UART0 TX/RX — used by the serial console / ESPHome logger |

---

### ⚠️ CAUTION — Strapping Pins

These pins control boot behaviour. They can be used as regular GPIOs **after** boot,
but must not be driven high or low by external hardware during the reset/boot sequence.

| GPIO | Boot / Strapping Function |
|------|--------------------------|
| GPIO 0  | Must be HIGH for normal boot; LOW enters download mode |
| GPIO 3  | JTAG enable strapping |
| GPIO 45 | VDD_SPI voltage select (3.3 V / 1.8 V) |
| GPIO 46 | ROM serial download mode enable |

---

### ✅ ALLOWED / SAFE — General Use

The following pins have no internal conflicts and are safe for sensors, buses,
relays, LEDs, and other peripherals:

```
GPIO 4–18, 21, 35–42, 47, 48
```

---

## Bus Assignments

### I2C Bus
Used by: ADS1115 (ADC for NTC thermistors)

| Signal | GPIO |
|--------|------|
| SDA    | GPIO 21 |
| SCL    | GPIO 47 |

### 1-Wire Bus
Used by: DS18B20 digital temperature sensor(s)

| Signal     | GPIO |
|------------|------|
| Data / DQ  | GPIO 48 |

> **Pull-up:** A 4.7 kΩ resistor between GPIO 48 and 3.3 V is required for reliable
> 1-Wire communication.

---

## Sensor Pin Map (summary)

| Sensor            | Protocol | GPIO(s)         | Notes |
|-------------------|----------|-----------------|-------|
| ADS1115           | I2C      | SDA=21, SCL=47  | Address: 0x48 (ADDR → GND) |
| NTC1-RIMS         | Analog   | ADS1115 A0      | Via ADS1115 channel 0 |
| NTC2-MASH         | Analog   | ADS1115 A1      | Via ADS1115 channel 1 |
| DS18B20 (1-Wire)  | 1-Wire   | GPIO 48         | 4.7 kΩ pull-up required |

---

## Reserved for Future Use

| GPIO | Intended Use |
|------|-------------|
| GPIO 4  | TBD — see Brewing - Sofware notes |
| GPIO 5  | TBD — see Brewing - Sofware notes |
| GPIO 6  | TBD — see Brewing - Sofware notes |
| GPIO 7  | TBD — see Brewing - Sofware notes |
| GPIO 35–40 | TBD — expansion / relay outputs |

---

## Change Log

| Date       | Author | Change |
|------------|--------|--------|
| 2026-08-25 | singularity init | Initial GPIO map created; I2C and 1-Wire buses assigned |
