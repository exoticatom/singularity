# gpio_map.md
# GPIO Map — ESP32-S3-WROOM-1

**Project:** singularity | **Last updated:** 2026-08-26

Single source of truth for all hardware pin assignments. Every GPIO used in firmware or configuration must be recorded here first.

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
Used by: [ADS1115](expansion_boards.md) (ADC for [NTC](ntc.md) thermistors)

| Signal | GPIO |
|--------|------|
| SDA    | GPIO 21 |
| SCL    | GPIO 47 |

### 1-Wire Bus
Used by: [DS18B20](ds18b20.md) digital temperature sensor(s)

| Signal     | GPIO |
|------------|------|
| Data / DQ  | GPIO 48 |

> **Pull-up:** A 4.7 kΩ resistor between GPIO 48 and 3.3 V is required for reliable
> 1-Wire communication.

---

## Sensor Pin Map (summary)

| Sensor | Protocol | GPIO(s) | ROM / Address | Notes |
|---|---|---|---|---|
| ADS1115 | I2C | SDA=21, SCL=47 | 0x48 (ADDR → GND) | 16-bit ADC |
| NTC1-RIMS | Analog | ADS1115 A0 | — | Via ADS1115 channel 0 |
| NTC2-MASH | Analog | ADS1115 A1 | — | Via ADS1115 channel 1 |
| DS18B20-Boil | 1-Wire | GPIO 48 | `0x750000105cbe3528` | Boil kettle — this installation |
| DS18B20-HLT | 1-Wire | GPIO 48 | `0x3100000c31dd5a28` | Hot Liquor Tank — this installation |
| SSR1 | GPIO out | GPIO 41 | — | Spare SSR relay — RESTORE_DEFAULT_OFF |
| SSR2 | slow_pwm output | GPIO 42 | — | RIMS heating element — RESTORE_DEFAULT_OFF |

> **Note:** DS18B20 ROM addresses are unique per physical sensor. The addresses
> above are specific to this hardware installation. If a sensor is replaced,
> re-run ROM discovery (set DEBUG logging, reboot) to get the new address.

---

## Reserved for Future Use

| GPIO | Intended Use |
|------|-------------|
| GPIO 4  | TBD — expansion / future use |
| GPIO 5  | TBD — expansion / future use |
| GPIO 6  | TBD — expansion / future use |
| GPIO 7  | TBD — expansion / future use |
| GPIO 35–40 | TBD — expansion / relay outputs |

---

## Change Log

| Date       | Author | Change |
|------------|--------|--------|
| 2026-08-25 | singularity init | Initial GPIO map created; I2C and 1-Wire buses assigned |
| 2026-08-25 | singularity | Secrets reference section added; all keys documented |
| 2026-08-25 | singularity | Verified: all secrets aligned to `singularity_` prefix convention |
| 2026-08-26 | singularity | Added schematics, planned expansions, sensor polling and EMA filter docs |

---

## Secrets Configuration (Manual — Do Not Commit)

The following keys must be present in the **global `secrets.yaml`** on the
[Home Assistant](../home_assistant.md) instance (Raspberry Pi). This file is managed manually on the
device and is **never committed to the repository**.

```yaml
# ── Wi-Fi — main network (existing devices) ───────────────────────────────────
wifi_ssid: "<your-main-ssid>"
wifi_password: "<your-password>"

# ── singularity — ESP32-S3 brewing controller ─────────────────────────────────
singularity_wifi_ssid: "<your-singularity-ssid>"
singularity_wifi_password: "<your-password>"
singularity_ap_password: "<your-password>"
singularity_api_encryption_key: "<32-byte-base64-key>"
singularity_ota_password: "<your-password>"
```

### Key Reference

| Secret Key | Used In | Purpose |
|---|---|---|
| `wifi_ssid` | other ESP devices | SSID for the main network |
| `wifi_password` | other ESP devices | Password for the main network |
| `singularity_wifi_ssid` | `esp32_singularity.yaml` | SSID for the singularity network |
| `singularity_wifi_password` | `esp32_singularity.yaml` | Password for the singularity network |
| `singularity_ap_password` | `esp32_singularity.yaml` | Fallback AP hotspot password |
| `singularity_api_encryption_key` | `esp32_singularity.yaml` | Native API encryption (HA ↔ ESP32) |
| `singularity_ota_password` | `esp32_singularity.yaml` | OTA firmware update password |

### Rules

- All singularity secrets use the `singularity_` prefix to avoid collision with other devices.
- `wifi_ssid` / `wifi_password` belong to the main network — never reference them in singularity configs.
- The `secrets.yaml` file must **never** be committed to Git. Add it to `.gitignore` if not already present.
- The `singularity_api_encryption_key` was generated on 2026-08-25. If regenerated, reflash the device — the key is baked into the firmware.

---

## Schematics

### General Rule — ADC Input Filtering

Every [ADS1115](expansion_boards.md) analog input (A0–A3 on both chips) has a **100 nF ceramic capacitor**
connected between the input pin and GND. This filters high-frequency interference
from switching power supplies, pump motors, relays, and RF noise — all common in a
brewing environment. The capacitor is placed as close to the ADS1115 pin as possible.

```
ADS1115 Ax ──┬──► signal source
             │
           100nF
             │
            GND
```

This applies to all 4 ADC ports (ADC_Port_0 through ADC_Port_3) — all on ADS1115 #1 (0x48).

---

### NTC Thermistor Circuit (per channel)

Used for: [NTC1-RIMS](ntc.md) (ADC_Port_0), [NTC2-MASH](ntc.md) (ADC_Port_1)

**Principle:** Voltage divider between a fixed 10 kΩ resistor and the NTC thermistor.
The junction voltage changes with temperature and is read by the [ADS1115](expansion_boards.md).

```
3.3V
 │
 R_fixed (10kΩ, 1%)
 │
 ├──────────────────── ADS1115 input (A0 or A1)
 │                           │
 │                         100nF  ← HF filter cap
 │                           │
 NTC (10kΩ @ 25°C, B=3950)  GND
 │
GND
```

**Both NTC channels on ADS1115 #1:**

```
          3.3V
           │
     ┌─────┴─────┐
     │           │
   R1(10kΩ)   R2(10kΩ)
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

**ADS1115 #1 connections:**

```
ADS1115 (0x48)
 ├── VDD  → 3.3V
 ├── GND  → GND
 ├── SDA  → ESP32 GPIO 21
 ├── SCL  → ESP32 GPIO 47
 ├── ADDR → GND  (I2C address 0x48)
 ├── A0   → NTC1-RIMS junction  (+ 100nF to GND)
 ├── A1   → NTC2-MASH junction  (+ 100nF to GND)
 ├── A2   → spare               (+ 100nF to GND)
 └── A3   → spare               (+ 100nF to GND)
```

**Component list:**

| Component | Value | Notes |
|---|---|---|
| R_fixed (R1, R2) | 10 kΩ 1% | Between 3.3V and NTC junction |
| NTC (T1, T2) | 10 kΩ @ 25°C, B=3950 | Between junction and GND |
| C_filter (C1, C2) | 100 nF ceramic | Between junction and GND — HF filter |

**Sensor polling and filtering:**

| Parameter | Value | Notes |
|---|---|---|
| Update interval | 1s | All temperature sensors read every second |
| NTC filter chain | Lambda → sliding average (5) → EMA α=0.25 | Three-stage filter |
| DS18B20 filter | EMA α=0.25 | Single-stage filter |
| Build version | 60s | Version string published every minute |

**Exponential Moving Average (EMA) — α=0.25:**

Each new reading contributes 25% to the output; the previous output contributes 75%.

```
output = 0.25 × new_reading + 0.75 × previous_output
```

This smooths rapid noise while still tracking real temperature changes within a few seconds. Lower α = smoother but slower response. Higher α = faster but noisier.

**Key rules:**
- 3.3V reference only — never 5V on ADS1115 inputs
- All grounds tied together (ESP32, ADS1115, PSU)
- Use twisted pair cable for sensor runs longer than 30 cm
- Measure R_fixed with a multimeter and update the ESPHome lambda if it deviates from 10 kΩ

---

### DS18B20 1-Wire Circuit

Used for: [DS18B20](ds18b20.md)-Kettle (GPIO 48)

```
3.3V
 │
 R_pullup (4.7 kΩ)
 │
 ├──────────────────── ESP32 GPIO 48 (1-Wire DQ)
 │
 DS18B20 DQ pin

DS18B20:
 ├── VDD → 3.3V   (or leave floating for parasitic power mode)
 ├── GND → GND
 └── DQ  → GPIO 48 junction
```

**Key rules:**
- 4.7 kΩ pull-up resistor between GPIO 48 and 3.3V is mandatory
- For cable runs over 1 m, reduce pull-up to 2.2 kΩ
- In parasitic power mode (VDD floating) limit cable length to 30 cm

---

### Board Overview

![ESP32-S3-DEV-KIT-NXRX board components](assets/ESP32-S3-Devkit-n16r8_2.jpg)

| Component | Description |
|---|---|
| Module | ESP32-S3-WROOM series |
| USB | USB Type-C (USB & UART combined) |
| USB to UART | Built-in converter for serial flashing |
| USB HUB | On-board USB hub |
| Boot Button | Hold during reset to enter download mode |
| Reset Button | Resets the MCU |
| RGB LED | Connected to GPIO 38 (WS2812) |
| 3.3V Regulator | 5V → 3.3V on-board |
| 3.3V Indicator | PWR LED confirms 3.3V rail is live |

---

### Full Pinout Diagram

![ESP32-S3-DEV-KIT-NXRX pinout](assets/ESP32-S3-Devkit-n16r8.jpg)

### Pin Legend

| Colour | Function |
|---|---|
| Purple | ADC (Analog-to-Digital Converter) |
| Cyan | JTAG / USB |
| Orange | Touch sensor input |
| Grey | Serial (debug/programming) |
| Yellow-green | Miscellaneous / SPI |
| Blue | RTC power domain |
| Green | GPIO input/output |
| Yellow | Other related functions |
| Pink | Strapping pins |
| Red | CLK output |
| Red (PWR) | Power rails (3.3V and 5V) |
| Black | Ground |

### singularity Pin Assignments Cross-Reference

| GPIO | Board label | Our use | Safe? |
|---|---|---|---|
| GPIO 21 | RTC | I2C SDA | ✅ |
| GPIO 47 | SPICLK_P | I2C SCL | ✅ |
| GPIO 48 | SPICLK_N | 1-Wire DS18B20 | ✅ |
| GPIO 43 | U0TXD | RESERVED — UART0 TX | ❌ |
| GPIO 44 | U0RXD | RESERVED — UART0 RX | ❌ |
| GPIO 19 | USB_D− | RESERVED — USB | ❌ |
| GPIO 20 | USB_D+ | RESERVED — USB | ❌ |
| GPIO 46 | LOG | CAUTION — strapping | ⚠️ |
| GPIO 0 | BOOT | CAUTION — strapping | ⚠️ |
| GPIO 45 | VSPI | CAUTION — strapping | ⚠️ |
| GPIO 38 | RGB LED | On-board RGB LED | ℹ️ avoid if not using LED |

---

## Planned Expansions



### [MCP4728](expansion_boards.md) DAC — Analog Outputs

| Item | Detail |
|---|---|
| MCP4728 #1 | `0x60` (default) — DAC_Port_0 proportional valve, D1-D3 spare |
| MCP4728 #2 | `0x61` (reprogrammed via Arduino IDE) — DAC_Port_4–7 spare |
| Output signal | 0-3.3V → external V-to-I module for 4-20mA valve control |

---

### [YF-S200](yf_s200.md) Hall Effect Flow Sensor

The [YF-S200](yf_s200.md) is a pulse-output flow sensor (Hall effect), not analog 4-20mA.
It does **not** connect to the [ADS1115](expansion_boards.md) — it connects directly to an [ESP32](esp32.md) GPIO pin.

**Power supply:** 5V (required — sensor does not work reliably at 3.3V)

**Signal output:** open collector pulse, ~450 pulses per litre

**⚠️ Signal level problem:** sensor is powered at 5V but ESP32-S3 GPIO is 3.3V max.
The signal line must be stepped down before connecting to the GPIO.

#### Option A — Voltage Divider (for reference)

Use two resistors to divide the 5V signal to 3.3V:

```
YF-S200 signal out
        │
      10kΩ (R_top)
        │
        ├──────────────► ESP32 GPIO (3.3V safe)
        │
      20kΩ (R_bottom)
        │
       GND
```

Voltage at GPIO = 5V × 20kΩ / (10kΩ + 20kΩ) = 3.33V ✅

| Component | Value | Notes |
|---|---|---|
| R_top | 10 kΩ | Between YF-S200 signal and GPIO junction |
| R_bottom | 20 kΩ | Between GPIO junction and GND |

#### Option B — Internal Pull-up (recommended)

Since the YF-S200 output is open collector it only pulls the line LOW and
never drives it HIGH to 5V. With the ESP32 internal pull-up enabled the line
sits at 3.3V and pulses to GND — no external resistors needed on signal line.

```
5V ──── YF-S200 VCC
GND ─── YF-S200 GND
        YF-S200 signal ──── ESP32 GPIO
                            (internal pull-up enabled in ESPHome)
```

#### Decision

Use **Option B** (internal pull-up) for short cable runs — simpler, no extra
components. Switch to Option A (voltage divider) if signal integrity issues
occur with cables longer than ~1 m.

#### ESPHome config (when implemented)

```yaml
sensor:
  - platform: pulse_counter
    pin:
      number: GPIOX        # assign a safe GPIO from gpio_map.md ALLOWED list
      mode:
        input: true
        pullup: true        # internal 3.3V pull-up
    name: "YF-S200 Flow"
    unit_of_measurement: "L/min"
    update_interval: 10s
    filters:
      - multiply: 0.00221  # 450 pulses/L → L/min at 10s update interval
```
