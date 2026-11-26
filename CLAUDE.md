# openshell-orca

Workload image for running Orca server and its bots, with Claude Code and Codex, in NVIDIA OpenShell sandboxes. Read README.md for the layout and GLOSSARY.md for the terms; decisions are in docs/adr/.

Everything in this repo is in English.

## Check command

```sh
prek run --all-files && prek run --all-files --hook-stage manual
```

CI runs the same (`.github/workflows/guardrails.yml`). Run it before reporting a change done.

## Invariants

- The image runs as numeric `1500:1500` with `HOME=/sandbox`, an empty `/etc/machine-id` and no `ORCA_INSTANCE_ID`: Orca's pairing lives in the workspace and must survive an image update.
- Binaries stay at fixed root-owned paths (`/usr/local/bin/claude`, `/usr/local/bin/codex`): the providers' `binaries` lists match them.
- Every download is checked against a SHA-256 from `scripts/resolve-versions`.
- No credential ever goes in the image, the repo or a sandbox's environment: providers hold them (ADR 0001).
