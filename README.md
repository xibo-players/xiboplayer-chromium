# Xibo Player — Chromium Kiosk (Self-contained)

Self-contained Xibo digital signage player for kiosk deployments on Fedora, RHEL, Ubuntu, and Debian.

## What It Does

- **Bundles the PWA player** — no external PWA server needed
- Runs a local Node.js server that serves the player and proxies CMS API requests
- Launches Chromium in kiosk mode pointing at `http://localhost:8765`
- Auto-restarts the browser if it crashes
- Disables screen blanking and DPMS (X11 and Wayland)
- Starts automatically on user login via a systemd user service
- First-run setup page — enter CMS URL, key, and display name in the browser

## Architecture

```
┌─────────────────────────────────────────┐
│  Chromium (kiosk mode)                  │
│  http://localhost:8765/player/pwa/      │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│  Node.js Server (localhost:8765)        │
│  ├─ /player/pwa/*  → bundled PWA files  │
│  ├─ /xmds-proxy    → CMS SOAP API      │
│  ├─ /rest-proxy     → CMS REST API      │
│  └─ /file-proxy     → CMS media files   │
└───────────────┬─────────────────────────┘
                │
         ┌──────▼──────┐
         │  Xibo CMS   │
         └─────────────┘
```

## Installation

### From the package repository (recommended)

**Fedora/RHEL:**
```bash
sudo dnf config-manager addrepo --from-repofile=https://dnf.xiboplayer.org/rpm/xibo-players.repo
sudo dnf install xiboplayer-chromium
```

**Ubuntu/Debian:**
```bash
curl -fsSL https://dnf.xiboplayer.org/deb/GPG-KEY.asc | sudo gpg --dearmor -o /usr/share/keyrings/xibo-players.gpg
sudo curl -fsSL https://dnf.xiboplayer.org/deb/xibo-players.sources -o /etc/apt/sources.list.d/xibo-players.sources
sudo apt update && sudo apt install xiboplayer-chromium
```

### From local build

```bash
sudo dnf install nodejs rpm-build    # build deps
./build-rpm.sh
sudo dnf install dist/xiboplayer-chromium-*.noarch.rpm
```

## Configuration

On first run, Chromium opens the PWA setup page where you enter your CMS URL, key, and display name. No manual config editing needed.

An optional config file at `~/.config/xiboplayer/config.json` controls browser settings:

```json
{
  "browser": "chromium",
  "extraBrowserFlags": ""
}
```

| Key | Description |
|-----|-------------|
| `browser` | Browser binary: `chromium` (default) or `google-chrome-stable` |
| `extraBrowserFlags` | Additional Chromium flags (space-separated) |

## Keyboard Shortcuts

All overlays and controls are hidden by default for clean kiosk operation.

| Key | Action |
|-----|--------|
| `T` | Toggle timeline overlay — shows upcoming scheduled layouts with conflict indicators |
| `D` | Toggle download overlay — shows media download progress |
| `V` | Toggle video controls — show/hide native browser controls on all videos |
| `→` / `PageDown` | Skip to next layout |
| `←` / `PageUp` | Go to previous layout |
| `Space` | Pause / resume playback |
| `R` | Revert to scheduled layout (when manually overridden) |

Timeline overlay also supports **click-to-skip** — click any layout in the timeline to jump directly to it.

## Usage

```bash
# First run — creates config file
xiboplayer

# Edit config
nano ~/.config/xiboplayer/config.json

# Run manually
xiboplayer

# Enable auto-start on login
systemctl --user enable --now xiboplayer-kiosk.service

# Check status / logs
systemctl --user status xiboplayer-kiosk.service
journalctl --user -u xiboplayer-kiosk.service -f
```

## Building

### RPM
```bash
sudo dnf install nodejs rpm-build
./build-rpm.sh [version] [release]
```

### DEB
```bash
sudo apt install nodejs dpkg-dev
./build-deb.sh [version] [release]
```

The build scripts fetch the PWA dist from a local sibling build (`../xiboplayer-pwa/dist/`) or from npm (`@xiboplayer/pwa`).

## Dependencies

- **Runtime:** Chromium (or Chrome), Node.js >= 18, jq, curl
- **Build:** Node.js, npm, rpmbuild (RPM) or dpkg-deb (DEB)
