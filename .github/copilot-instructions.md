# Singularity Project Rules

## Core Architecture

* **ESP32 Autonomy (Critical):** The ESP32-S3 is a **fully autonomous brewing controller**. It must remain fully operational — reading sensors, running PID, controlling SSR relays — even when Home Assistant is completely offline or unreachable. HA going down must never stop or degrade a brew in progress. All critical state (calibration, PID params, SSR state) is persisted to ESP32 flash and restored on reboot.

* **Role Separation:** The ESP32-S3 acts as an **intelligent sensor and controller** — not a dumb data collector. It sends processed data (temperatures in °C, flow rates in L/min, control signals) to HA. Raw voltage readings are available for diagnostics only and are not the primary data path.

* **HA as Augmentation:** Home Assistant receives pre-calculated values from the ESP32 and augments them with dashboards, automations, and notifications. These enhancements do NOT replace the ESP32's core functionality. If HA restarts mid-brew, the ESP32 continues unaffected.

* **Flash Persistence:** All calibration parameters (NTC Steinhart-Hart coefficients, DS18B20 offsets, PID Kp/Ki/Kd, flow offsets) are stored on ESP32 flash using `restore_value: true`. A power loss mid-brew resumes with the same tuning on the next boot.

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
