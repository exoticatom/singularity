# ESP32-S3-DEV-KIT-NXRX

The singularity controller is built on the ESP32-S3-DEV-KIT-NXRX development board featuring the ESP32-S3-WROOM module.

---

## Board Overview

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-S3-Devkit-n16r8_2.jpg" width="50%"/>

| Component | Description |
|---|---|
| Module | ESP32-S3-WROOM series |
| USB | USB Type-C (USB & UART combined) |
| Boot Button | Hold during reset → download mode |
| Reset Button | Resets the MCU |
| RGB LED | GPIO 38 (WS2812) |
| 3.3V Regulator | 5V → 3.3V on-board |
| Flash | 16MB |
| PSRAM | 8MB |

---

## Pinout Diagram

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-S3-Devkit-n16r8.jpg" width="50%"/>

---

## singularity Wiring Summary

| GPIO | Function | Role | Status |
|---|---|---|---|
| GPIO 21 | SDA | I2C data — ADS1115 | ✅ in use |
| GPIO 47 | SCL | I2C clock — ADS1115 | ✅ in use |
| GPIO 48 | 1-Wire DQ | DS18B20 sensors | ✅ in use |
| GPIO 41 | Output | SSR1 relay | ✅ in use |
| GPIO 42 | Output | SSR2 RIMS Heater relay | ✅ in use |
| GPIO 43 | U0TXD | UART0 TX — serial console | ❌ reserved |
| GPIO 44 | U0RXD | UART0 RX — serial console | ❌ reserved |
| GPIO 19 | USB_D− | USB data | ❌ reserved |
| GPIO 20 | USB_D+ | USB data | ❌ reserved |
| GPIO 26–32 | Flash/PSRAM | Internal — do not use | ❌ reserved |
| GPIO 0 | BOOT | Strapping pin | ⚠️ caution |
| GPIO 45 | VSPI | Strapping pin | ⚠️ caution |
| GPIO 46 | LOG | Strapping pin | ⚠️ caution |

See [gpio_map.md](gpio_map.md) for full pin rules, reserved pins and available GPIO list.

---

## ESP32-S3 Key Specs

| Parameter | Value |
|---|---|
| CPU | Xtensa dual-core LX7, up to 240MHz |
| Wi-Fi | 802.11 b/g/n (2.4GHz) |
| Bluetooth | BLE 5.0 |
| GPIO | 45 programmable pins |
| ADC | 2 × 12-bit SAR ADC (but use ADS1115 for accuracy) |
| I2C | 2 × hardware I2C controllers |
| SPI | 4 × SPI |
| UART | 3 × UART |
| Operating voltage | 3.3V |

---

## First Flash

See [Step 5](../README.md#step-5--first-flash-usb) in the main README for flashing options (local CLI, web flasher, OTA).
