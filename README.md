# Xibo Player — Chromium Kiosk (Self-contained)

Self-contained Xibo digital signage player for kiosk deployments on Fedora, RHEL, Ubuntu, and Debian.

## What It Does

- **Bundles the PWA player** — no external PWA server needed
- Runs a local Node.js server that serves the player and proxies CMS API requests
- Launches Chromium in kiosk mode pointing at `http://localhost:8766`
- Auto-restarts the browser if it crashes
- Disables screen blanking and DPMS (X11 and Wayland)
- Starts automatically on user login via a systemd user service
- First-run setup page — enter CMS URL, key, and display name in the browser

## Architecture

```
┌─────────────────────────────────────────┐
│  Chromium (kiosk mode)                  │
│  http://localhost:8766/player/pwa/      │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│  Node.js Server (localhost:8766)        │
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
sudo dnf install \
  https://github.com/xibo-players/xibo-players.github.io/releases/download/v43-5/xiboplayer-release-43-5.noarch.rpm
sudo dnf install xiboplayer-chromium
```

**Ubuntu/Debian:**
```bash
curl -fsSL https://dl.xiboplayer.org/deb/GPG-KEY.asc | sudo gpg --dearmor -o /usr/share/keyrings/xibo-players.gpg
sudo curl -fsSL https://dl.xiboplayer.org/deb/xibo-players.sources -o /etc/apt/sources.list.d/xibo-players.sources
sudo apt update && sudo apt install xiboplayer-chromium
```

### From local build

```bash
sudo dnf install nodejs rpm-build    # build deps
./build-rpm.sh
sudo dnf install dist/xiboplayer-chromium-*.noarch.rpm
```

## Configuration

### CMS config — `config.json` (recommended for provisioning)

Place a CMS config file at `~/.config/xiboplayer/chromium/config.json` before first launch:

```json
{
  "cmsUrl": "https://your-cms.example.com",
  "cmsKey": "your-cms-key",
  "displayName": "Lobby Display"
}
```

On first boot, the server reads this file and injects the CMS configuration into the PWA via localStorage. The player registers with the CMS and shows a setup screen while it waits for administrator authorization. Once authorized, it starts playing.

If no config file is present, Chromium opens the PWA setup page where you enter your CMS URL, key, and display name interactively.

### Auto-authorize via CMS API (optional)

By default, new displays must be manually authorized by a CMS administrator. To skip this step, add OAuth2 API credentials to `config.json` — see the [PWA README](https://github.com/xibo-players/xiboplayer-pwa#auto-authorize-via-cms-api-optional) for full setup instructions including CMS Application configuration:

```json
{
  "cmsUrl": "https://your-cms.example.com",
  "cmsKey": "your-cms-key",
  "displayName": "Lobby Display",
  "apiClientId": "your-client-id",
  "apiClientSecret": "your-client-secret"
}
```

You can also enter the API credentials interactively in the setup page under "Auto-authorize via API".

### Display and kiosk settings

All display settings can be configured in `config.json`:

| Key | Default | Description |
|-----|---------|-------------|
| `browser` | `"chromium"` | Browser binary: `chromium` or `google-chrome-stable` |
| `extraBrowserFlags` | `""` | Additional Chromium flags (space-separated) |
| `kioskMode` | `true` | Lock browser chrome (no address bar, tabs, or close button) |
| `fullscreen` | `true` | Start in fullscreen (when kiosk mode is off) |
| `hideMouseCursor` | `true` | Hide cursor after inactivity (requires `unclutter`) |
| `preventSleep` | `true` | Disable screen blanking and DPMS |
| `width` / `height` | `1920` / `1080` | Window size (when kiosk mode is off) |

### Keyboard and mouse controls

All keyboard shortcuts and mouse hover behavior are **disabled by default** for secure kiosk operation. Enable them in the `controls` section of `config.json`:

```json
{
  "controls": {
    "keyboard": {
      "debugOverlays": true,
      "setupKey": true,
      "playbackControl": true,
      "videoControls": true
    },
    "mouse": {
      "statusBarOnHover": true
    }
  }
}
```

When enabled, the following shortcuts are available:

| Key | Group | Action |
|-----|-------|--------|
| `D` | `debugOverlays` | Toggle download progress overlay |
| `T` | `debugOverlays` | Toggle timeline overlay (click-to-skip supported) |
| `S` | `setupKey` | Toggle CMS setup screen |
| `V` | `videoControls` | Toggle native `<video>` controls |
| `→` / `PageDown` | `playbackControl` | Skip to next layout |
| `←` / `PageUp` | `playbackControl` | Skip to previous layout |
| `Space` | `playbackControl` | Pause / resume playback |
| `R` | `playbackControl` | Revert to scheduled layout |
| Media keys | `playbackControl` | Next/prev/pause/play (MediaSession API) |

See [CONFIG.md](CONFIG.md) for full configuration reference.

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

## Multiple Displays

Run multiple independent player instances on the same machine using `--instance=NAME`. Each instance gets its own config, browser profile, and server port:

```bash
# Instance "lobby" — port 8766 (default)
xiboplayer --instance=lobby

# Instance "cafeteria" — port 8767
xiboplayer --instance=cafeteria --port=8767
```

Each instance uses isolated paths:

| | Default (no instance) | `--instance=lobby` |
|---|---|---|
| **Config** | `~/.config/xiboplayer/chromium/` | `~/.config/xiboplayer/chromium-lobby/` |
| **Browser data** | `~/.local/share/xiboplayer/chromium/` | `~/.local/share/xiboplayer/chromium-lobby/` |
| **Lock file** | `/tmp/xiboplayer-kiosk.lock` | `/tmp/xiboplayer-kiosk-lobby.lock` |

### Setup

1. Create a config for each instance:
```bash
mkdir -p ~/.config/xiboplayer/chromium-lobby
cat > ~/.config/xiboplayer/chromium-lobby/config.json << 'EOF'
{
  "cmsUrl": "https://cms.example.com",
  "cmsKey": "your-key",
  "displayName": "Lobby Display",
  "serverPort": 8766
}
EOF
```

2. Create a systemd service per instance (or use `--port` to override):
```bash
# Copy and customize the service file
cp ~/.config/systemd/user/xiboplayer-kiosk.service \
   ~/.config/systemd/user/xiboplayer-lobby.service
# Edit: ExecStart=/usr/bin/xiboplayer --instance=lobby
systemctl --user enable --now xiboplayer-lobby.service
```

Each instance registers as a separate display in the CMS.

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
