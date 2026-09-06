# Rule: Entity Sync

## Rule 1 — Keep esp32_singularity.yaml in sync with entity changes

**Every time an entity is added, removed, or renamed** (sensor, number, switch, button, binary_sensor, text_sensor) the following must be updated in the same commit:

- `esp32_singularity.yaml` — the entity definition itself
- The inline `# → entity.id` comment on the `name:` line
- The file header entity list (if it exists for that section)
- `home_assistant.md` — entity map section
- `singularity_dashboard.yaml` — any card referencing the entity
- `hardware/calibration.md` — if the entity is calibration-related
- `README.md` — if it affects the project status tables

## Rule 2 — Check for orphaned HA entities after every entity change

**Every time an entity is removed or renamed**, check Home Assistant for orphaned entities and report them to the user.

An orphaned entity is one that:
- Exists in the HA entity registry (`/config/.storage/core.entity_registry`)
- No longer has a matching definition in `esp32_singularity.yaml`
- Is not referenced in any dashboard card

**How to check:**
SSH to the Pi and grep for the old entity ID:
```bash
grep -o '"entity_id":"[^"]*singularity[^"]*"' /config/.storage/core.entity_registry | sort
```

Then cross-reference against the current firmware entities.

**Report to the user:**
List the orphaned entities and ask the user to delete them from:
HA → Settings → Devices & Services → Entities → search → Delete

## What does NOT require an entity sync check

- Firmware logic changes (PID tuning values, filter alpha, thresholds)
- Comment-only changes
- Dashboard layout changes that don't add/remove entity references
- Documentation prose changes
