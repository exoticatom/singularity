# Rule: Deployment Requires Review & Approval

**The user reviews all changes before they leave the local workspace.** Never
deploy to git, Home Assistant, or the ESP32 without explicit user approval.

Since every push to `main` auto-deploys the dashboard + templates to HA via
CI/CD, pushing to git IS deploying to HA. Treat all three paths as gated.

## Three gated deployment paths

### 1. Git push (also triggers HA auto-deploy via CI/CD)
- Local `git add` / `git commit` is allowed — the user can review or revert.
- **Never `git push`** without asking. A push to `main` auto-deploys the
  dashboard and templates to the Pi.
- When ready: commit locally, then ask "Ready to push to git — go ahead?"

### 2. Home Assistant (dashboard, templates, automations)
- Never write dashboard/template/automation changes directly to the Pi
  (SSH, rsync, file copy) without approval.
- Normal path is via git push + CI/CD — so the git approval covers this.
- Any direct HA file change requires explicit approval.

### 3. ESP32 firmware (flashing)
- **Never run `esphome run` / `esphome upload` / OTA flash** without approval.
- The user flashes the ESP32 themselves, or explicitly asks Kiro to.
- Editing `esp32_singularity.yaml` locally is fine — flashing it is not.

## Workflow

1. Make the change locally (edit files, commit locally).
2. Show the user what changed (diff / summary).
3. Ask before: pushing to git, writing to HA, or flashing the ESP32.
4. Wait for a clear yes for that specific action.

## Allowed without asking
- `git add`, `git commit` (local only)
- `git status`, `git log`, `git diff`, `git pull` (read-only / sync)
- Editing any file in the workspace
- `esphome config` / `esphome compile` (validate/build only — no upload)

## Requires explicit approval
- `git push` (any remote/branch)
- Any direct write to the HA Pi (SSH/rsync/scp of config)
- `esphome run` / `esphome upload` / OTA flash to the ESP32
