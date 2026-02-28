# Chromium Kiosk Player Configuration

Configuration file: `~/.config/xiboplayer/chromium/config.json`

Copy the example to get started:

```bash
mkdir -p ~/.config/xiboplayer/chromium
cp config.json.example ~/.config/xiboplayer/chromium/config.json
```

## Full Reference

```jsonc
{
  // CMS connection — set via Setup screen (S key) or here
  "cmsUrl": "https://cms.example.com",
  "cmsKey": "your-server-key",
  "displayName": "Lobby Screen 1",

  // Local server port (default: 8766)
  "serverPort": 8766,

  // Browser engine (currently only "chromium")
  "browser": "chromium",

  // Extra flags passed to the Chromium process
  "extraBrowserFlags": "",

  // Kiosk and display settings
  "kioskMode": true,
  "fullscreen": true,
  "hideMouseCursor": true,
  "preventSleep": true,
  "width": 1920,
  "height": 1080,

  // CMS transport: "auto" (default) or "xmds" (force SOAP for unpatched Xibo CMS)
  "transport": "auto",

  // Google Geolocation API key (optional, improves location accuracy)
  "googleGeoApiKey": "",

  // Keyboard and mouse controls
  "controls": {
    "keyboard": {
      "debugOverlays": false,
      "setupKey": false,
      "playbackControl": false,
      "videoControls": false
    },
    "mouse": {
      "statusBarOnHover": false
    }
  }
}
```

## Display Settings

| Key | Default | Description |
|-----|---------|-------------|
| `kioskMode` | `true` | Chromium `--kiosk` flag — locks browser chrome completely |
| `fullscreen` | `true` | `--start-fullscreen` (only when kiosk mode is off) |
| `hideMouseCursor` | `true` | Hides cursor via `unclutter` (install: `sudo dnf install unclutter`) |
| `preventSleep` | `true` | Disables screen blanking and DPMS (X11 `xset` + GNOME `gsettings`) |
| `width` / `height` | `1920` / `1080` | Window size via `--window-size` (only when kiosk mode is off) |

When `kioskMode` is `true`, `fullscreen` and `width`/`height` are ignored — Chromium's `--kiosk` flag takes over.

## Transport

| Value | Description |
|-------|-------------|
| `"auto"` (default) | Try REST API first, fall back to SOAP if the CMS lacks REST endpoints |
| `"xmds"` | Force SOAP/XMDS transport — use this for unpatched Xibo CMS without REST API |

Omitting `transport` or setting it to any value other than `"xmds"` uses auto-detection.

## Google Geolocation API Key

Optional. Improves location accuracy from ~5 km (IP-based fallback) to ~50 m (Google API).

```json
{
  "googleGeoApiKey": "AIzaSy..."
}
```

The key is passed to the SDK via `playerConfig`. Without it, the player falls back to free IP-based geolocation providers — no key required.

## Media Capture

Webcam and microphone access is auto-approved via Chromium enterprise policies. The kiosk launch script writes `VideoCaptureAllowed`, `AudioCaptureAllowed`, and URL restrictions limiting capture to `localhost` only. No configuration needed.

## Controls

The `controls` section gates keyboard shortcuts and mouse behavior in the player. All controls default to `false` (disabled). Omitting `controls` entirely means no keyboard shortcuts or mouse hover will be active — a clean, locked-down kiosk.

### Keyboard

| Key | Group | Default | Action |
|-----|-------|---------|--------|
| `D` | `debugOverlays` | **false** | Toggle download progress overlay |
| `T` | `debugOverlays` | **false** | Toggle timeline/schedule overlay |
| `S` | `setupKey` | **false** | Toggle CMS setup screen |
| `V` | `videoControls` | **false** | Toggle native `<video>` controls |
| `ArrowRight` / `PageDown` | `playbackControl` | **false** | Skip to next layout |
| `ArrowLeft` / `PageUp` | `playbackControl` | **false** | Skip to previous layout |
| `Space` | `playbackControl` | **false** | Pause / resume playback |
| `R` | `playbackControl` | **false** | Revert to scheduled layout |
| Media keys | `playbackControl` | **false** | Next/prev/pause/play (MediaSession API) |

Set a group to `true` to enable keys in that group:

```json
{
  "controls": {
    "keyboard": {
      "setupKey": true,
      "playbackControl": true
    }
  }
}
```

### Mouse

| Setting | Default | Action |
|---------|---------|--------|
| `statusBarOnHover` | **false** | Show status bar (CMS URL, player status) when mouse hovers over the player |

Set to `true` to show the status bar during development:

```json
{
  "controls": {
    "mouse": {
      "statusBarOnHover": true
    }
  }
}
```

## Development Example

For development with all controls and debug overlays enabled:

```json
{
  "browser": "chromium",
  "cmsUrl": "https://cms.example.com",
  "cmsKey": "your-key",
  "displayName": "Lobby-1",
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

## Config Flow

```
config.json
  → server.js reads controls
    → passes to @xiboplayer/proxy as playerConfig
      → proxy injects into localStorage['xibo_config'].controls
        → PWA main.ts reads controls, gates keyboard handlers
        → PWA index.html reads controls, gates hover CSS
```

Changes to `config.json` require a player restart to take effect.
