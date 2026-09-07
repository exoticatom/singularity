# Singularity Project Rules

## Core Architecture

* **Role Separation:** The ESP32-S3 acts purely as a "dumb" generic data collector. It must only send raw voltage data. 

* **Logic Handoff:** All complex math, including Steinhart-Hart temperature calculations and SM6004 piece-wise linear flow lookups, must be handled dynamically in Home Assistant template sensors or Node-RED.

## Hardware Constraints (ESP32-S3-DevKitC-1)

* **RESERVED PINS (NEVER USE):** GPIO 26-32 (Flash/PSRAM), GPIO 19-20 (USB-JTAG), GPIO 43-44 (UART0).

* **CAUTION PINS:** GPIO 0, 3, 45, 46 (Strapping pins).

* **SAFE PINS:** GPIO 4-18, 21, 35-42, 47, 48.

* **Voltage Ceiling:** The ESP32 is strictly a 3.3V logic device. All analog modules (like the 4-20mA SM6004 converters) must be hardware-calibrated to a 0-3.3V scale to prevent pin damage. 

## Coding Standards (ESPHome)

* **Filtering:** Apply an `exponential_moving_average` filter with an `alpha` of `0.25` to all analog sensor inputs to suppress noise.

* **Dynamic Routing:** Do not hardcode specific sensor roles to physical pins in the firmware. Define generic ports (e.g., `adc_port_a0` on the ADS1115) and map them dynamically via Home Assistant `input_select` dropdown helpers.
