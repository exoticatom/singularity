# ESP32-S3 — Supported Boards

singularity runs on ESP32-S3 based development boards. Two boards have been tested and confirmed working. The firmware is identical for both — only physical dimensions differ.

---

## Board 1 — Waveshare ESP32-S3-DEV-KIT-N16R8

> 🔗 [Waveshare Wiki — ESP32-S3-DEV-KIT-N8R8](https://www.waveshare.com/wiki/ESP32-S3-DEV-KIT-N8R8) (page covers NxR8 variants including N16R8)

The initial board used during development.

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-S3-Devkit-n16r8_2.jpg" width="50%"/>

| Component | Description |
|---|---|
| Module | ESP32-S3-WROOM-1 N16R8 |
| Manufacturer | Waveshare |
| USB | USB Type-C (CH343 + CH334 — USB & UART) |
| Boot Button | Hold during reset → download mode |
| Reset Button | Resets the MCU |
| RGB LED | On-board |
| Flash | 16MB |
| PSRAM | 8MB |
| PCB size | 63.3 × 25.4mm |
| **Pin header span** | **21.8mm** — expansion board socket must match this width |
| Pin count | 44 pins |

> ⚠️ **Expansion board compatibility:** Board 1 requires an expansion board with a **21.8mm wide socket**. It is NOT compatible with expansion boards designed for 25.4mm boards.

### Pinout Diagram

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-S3-Devkit-n16r8.jpg" width="50%"/>

---

## Board 2 — ESP32-S3-WROOM-1 N16R8 44-Pin Type-C ✅ Active

Tested as a replacement during development. All firmware, calibration, and HA entities transferred without any changes. HA needed a few minutes to recognise the new IP for `singularity.local` but everything else worked immediately after flashing.

<img src="https://raw.githubusercontent.com/exoticatom/singularity/main/assets/ESP32-S3WROOM1 N16R8 44Pin Type-C ESP32-S3 - Board 2.jpg" width="50%"/>

| Component | Description |
|---|---|
| Module | ESP32-S3-WROOM-1 N16R8 |
| USB | USB Type-C (two ports — USB + UART) |
| Boot Button | Hold during reset → download mode |
| Reset Button | Resets the MCU |
| RGB LED | On-board |
| Flash | 16MB |
| PSRAM | 8MB |
| PCB size | 25.4mm wide |
| **Pin header span** | **25.4mm** — expansion board socket must match this width |
| Pin count | 44 pins |

| **Pin header span** | **25.4mm** — expansion board socket must match this width |
| Pin count | 44 pins |

> ⚠️ **Expansion board compatibility:** Board 2 requires an expansion board with a **25.4mm wide socket**. It is NOT compatible with expansion boards designed for 21.8mm boards (Board 1). The two boards use different expansion boards and are not interchangeable.

### First Flash — Download Mode Procedure

This board requires a specific button sequence to enter download mode for the first flash:

1. Press and hold **BOOT**
2. Press and release **RESET** (while still holding BOOT)
3. Release **RESET**
4. Release **BOOT**

Then immediately run:
```bash
esphome run esp32_singularity.yaml
```
Select the USB port option. After the first successful flash, all subsequent updates can be done via OTA.

---

## Firmware Compatibility

Both boards use the same ESPHome config with no changes:

```yaml
esp32:
  board: esp32-s3-devkitc-1
  framework:
    type: arduino
  variant: esp32s3
```

The `esp32-s3-devkitc-1` board identifier covers both variants — same chip, same GPIO layout, same flash/PSRAM specs.

---

## singularity GPIO Assignments (both boards)

| GPIO | Function | Role | Status |
|---|---|---|---|
| GPIO 21 | SDA | I2C data — [ADS1115](expansion_boards.md) | ✅ in use |
| GPIO 47 | SCL | I2C clock — [ADS1115](expansion_boards.md) | ✅ in use |
| GPIO 48 | 1-Wire DQ | [DS18B20](ds18b20.md) sensors | ✅ in use |
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
| ADC | 2 × 12-bit SAR ADC (but use [ADS1115](expansion_boards.md) for accuracy) |
| I2C | 2 × hardware I2C controllers |
| SPI | 4 × SPI |
| UART | 3 × UART |
| Operating voltage | 3.3V |

---

## First Flash

See [installation.md](../installation.md) for first flash options (web flasher, CLI, OTA).
