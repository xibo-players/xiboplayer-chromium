# Changelog

## 0.7.12 (2026-04-02)

### Build

- **Upgraded vite 8 and @types/node 25**.

### Bug Fixes

- **CI default-version synced** — Matched to 0.7.11.

### Testing

- **9 bats tests** — `cfg_read` JSON extraction, `load_config` full config, CLI argument parsing (`--port`, `--instance`, `--no-kiosk`).
- First test suite for this repo.

### Infrastructure

- **Dependabot** added for npm + GitHub Actions.
- **Dependencies updated** — pnpm update for server packages.

## 0.7.11 (2026-03-31)

- chore: bump version to 0.7.11
- feat: optional XIBOPLAYER_DEBUG_PORT for CDP monitoring (FPS, memory)
