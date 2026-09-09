# Singularity Project Rules

## Core Architecture

* **ESP32 Autonomy (Critical):** The ESP32-S3 is a **fully autonomous brewing controller**. It must remain fully operational — reading sensors, running PID, controlling SSR relays — even when Home Assistant is completely offline or unreachable. HA going down must never stop or degrade a brew in progress. All critical state (calibration, PID params, SSR state) is persisted to ESP32 flash and restored on reboot.

* **Role Separation:** The ESP32-S3 acts as an **intelligent sensor and controller** — not a dumb data collector. It sends processed data (temperatures in °C, flow rates in L/min, control signals) to HA. Raw voltage readings are available for diagnostics only and are not the primary data path.

* **HA as Augmentation:** Home Assistant receives pre-calculated values from the ESP32 and augments them with dashboards, automations, and notifications. These enhancements do NOT replace the ESP32's core functionality. If HA restarts mid-brew, the ESP32 continues unaffected.

* **Flash Persistence:** All calibration parameters (NTC Steinhart-Hart coefficients, DS18B20 offsets, PID Kp/Ki/Kd, flow offsets) are stored on ESP32 flash using `restore_value: true`. A power loss mid-brew resumes with the same tuning on the next boot.

## Safety (Non-Negotiable)

* **Firmware interlocks are the primary guard — and a single point of failure.** All thermal protection runs inside the 2s PID loop on the ESP32: 8s sensor-staleness watchdog, NAN guard, 90°C hard cutoff, RIMS flow interlock. A firmware hang, a crashed MCU with the SSR latched, or a stuck-HIGH GPIO defeats every software guard at once.

* **Independent hardware high-limit cutoff (REQUIRED before any live heating).** A bimetallic snap-disc / Klixon (~90–95°C) or a thermal fuse must be wired physically **in series with the SSR AC mains line** to the RIMS element, clamped to the element body, fully independent of the ESP32. Hardware prerequisite — **no mains-powered RIMS heating test may run until it is fitted.** Tracked in [README Project Status](../README.md#project-status) and [gpio_map.md → SSR Gate Circuit](../hardware/gpio_map.md#ssr-gate-circuit-gpio-41--42--pulldown-required). Planned as a one-time install — do not scaffold firmware around it.

* **Fail-safe direction:** guards force heater duty to 0% and `return`. Trips publish to `sensor.singularity_safety_event` (offline-persistent via the HA recorder).

* **Never weaken a guard for latency.** The flow interlock reads the fast `an1_flow_safety_v` (median(3), **no EMA**) specifically to avoid display-filter lag — this is the one deliberate exception to the α=0.25 EMA rule below. Do not route the interlock through the smoothed `an1_rate`.

## Hardware Constraints (ESP32-S3-DevKitC-1)

* **RESERVED PINS (NEVER USE):** GPIO 26-32 (Flash/PSRAM), GPIO 19-20 (USB-JTAG), GPIO 43-44 (UART0).

* **CAUTION PINS:** GPIO 0, 3, 45, 46 (Strapping pins).

* **SAFE PINS:** GPIO 4-18, 21, 35-42, 47, 48.

* **Voltage Ceiling:** The ESP32 is strictly a 3.3V logic device. All analog modules (like the 4-20mA SM6004 converters) must be hardware-calibrated to a 0-3.3V scale to prevent pin damage.

## Coding Standards (ESPHome)

* **Filtering:** Apply an `exponential_moving_average` filter with an `alpha` of `0.25` to all analog sensor inputs to suppress noise — including raw voltage diagnostic sensors (AN1/AN2).

* **Entity ID Convention:** All entities must follow the `singularity_` prefix pattern. HA entity IDs are auto-generated as `<platform>.singularity_<entity_name>`. Never reference bare `esp32_*` entity IDs in dashboards or automations — always use the full `singularity_esp32_*` form (e.g. `binary_sensor.singularity_esp32_fast_status`).

* **Dynamic Routing:** Do not hardcode specific sensor roles to physical pins in the firmware. Define generic ports (e.g., `adc_port_a0` on the ADS1115) and map them dynamically via Home Assistant `input_select` dropdown helpers.

* **Documentation Accuracy:** Comments and docs must reflect actual firmware behaviour. Temperatures and flow rates are calculated on the ESP32 (Steinhart-Hart, flow conversion). HA displays the results — it does not perform these calculations.
