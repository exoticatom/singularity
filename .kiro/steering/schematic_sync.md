# Rule: Schematic Sync

**Every time a GPIO assignment, pin connection, voltage, or module wiring changes, the schematics must be updated in the same commit.**

## Schematics that must stay in sync

| File | What it covers |
|---|---|
| `assets/schematics/singularity.svg` | Main schematic — power architecture, modules and connections |

## What triggers a schematic update

- Any GPIO number change (e.g. moving SDA from GPIO21 to another pin)
- Any new GPIO assignment added to firmware
- Any I2C address change
- Any new module added to the I2C bus or 1-Wire bus
- Any voltage change (e.g. changing a module from 3.3V to 5V)
- Any new sensor wired (NTC, DS18B20, flow meter, etc.)
- Any SSR or output pin change
- Any power rail change

## What does NOT require a schematic update

- Firmware logic changes (PID tuning, calibration values, offsets)
- Dashboard changes
- Documentation prose changes
- Adding HA entities that don't change physical wiring

## Process

1. Make the firmware/hardware change
2. Update `assets/schematics/singularity_schematic.svg` to reflect the new connection
3. Update `assets/schematics/singularity.svg` if the MCP4728/valve/shifter section changed
4. Update `hardware/schematic.md` component table if a new module was added or status changed
5. Include all schematic files in the same commit as the hardware/firmware change
