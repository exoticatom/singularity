# Rule: Git Push Requires Approval

**Never run `git push` without explicit user approval.**

- Making local commits is allowed (the user can review or revert them).
- Before pushing to the remote (`origin/main` or any branch), always ask the user first and wait for a clear yes.
- If the user says "commit", that means commit locally only — do NOT push unless they also say to push.
- If changes are ready to push, stage and commit them, then ask: "Ready to push to git — go ahead?"

## What is allowed without asking
- `git add`, `git commit` (local only)
- `git status`, `git log`, `git diff` (read-only)
- `git pull` (to stay in sync)

## What requires explicit approval
- `git push` (any remote, any branch)
