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

  // GPU selection: "auto" (default), "nvidia", "intel", "amd", or "/dev/dri/renderDNNN"
  "gpu": "auto",

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

## GPU Selection

The player auto-detects available GPUs via `/sys/class/drm` and selects the best one for compositing and video decode. It also sets the VA-API driver (`LIBVA_DRIVER_NAME`) to match.

| Value | Description |
|-------|-------------|
| `"auto"` (default) | Auto-detect (see hybrid GPU behavior below) |
| `"nvidia"` | Force NVIDIA GPU |
| `"intel"` | Force Intel GPU |
| `"amd"` | Force AMD GPU |
| `"/dev/dri/renderDNNN"` | Force a specific DRM render node |

**Override priority**: `--gpu=` CLI arg > `XIBO_GPU` env var > `config.gpu` > `"auto"`

```bash
# CLI
xiboplayer-chromium --gpu=nvidia

# Environment variable
XIBO_GPU=nvidia xiboplayer-chromium

# config.json
{ "gpu": "nvidia" }
```

On startup the player logs which GPUs were detected and which was selected:

```
[xiboplayer]   GPU:     nvidia 0x1f91 (nvidia) → /dev/dri/renderD129 (render-only)
[xiboplayer]   GPU:     intel 0x3e9b (i915) → /dev/dri/renderD128 (display)
[xiboplayer]   GPU:     selected intel → /dev/dri/renderD128 (pref: auto)
[xiboplayer]   GPU:     VA-API driver: iHD
```

### Hybrid GPU (Optimus/PRIME) behavior

On laptops with both a discrete GPU (NVIDIA/AMD) and an integrated GPU (Intel), only one GPU is wired to the display outputs. The other is a render-only offload GPU with no display connectors.

In `"auto"` mode the player **always picks the GPU that has display connectors**. On Wayland, the render-only GPU cannot share framebuffers with the display GPU (dmabuf cross-device transfer fails), so selecting it would produce a black screen.

| System | `auto` selects | Why |
|--------|---------------|-----|
| Laptop with Intel + NVIDIA (Optimus) | Intel | Intel drives the screen; NVIDIA is render-only |
| Desktop with NVIDIA driving monitor | NVIDIA | NVIDIA has the display connectors |
| Desktop with AMD driving monitor | AMD | AMD has the display connectors |
| Single GPU (any vendor) | That GPU | Only one choice |

To force the discrete GPU (e.g. for testing on X11 where PRIME offload works), use `--gpu=nvidia` or `"gpu": "nvidia"` in config.

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

## Config Templates

Reusable config templates with variable substitution and management scripts. Shipped in the RPM/DEB at `/usr/share/xiboplayer-chromium/configs/` and also in the source repo under `configs/`.

### Quick Start (RPM/DEB install)

```bash
# 1. Copy secrets example to your user config dir and fill in CMS credentials
mkdir -p ~/.config/xiboplayer
cp /usr/share/xiboplayer-chromium/configs/secrets.env.example ~/.config/xiboplayer/secrets.env
vi ~/.config/xiboplayer/secrets.env

# 2. Apply a template to create a player instance
/usr/share/xiboplayer-chromium/configs/apply.sh chromium-dev chromium            # dev mode with debug
/usr/share/xiboplayer-chromium/configs/apply.sh chromium-kiosk chromium           # production kiosk
/usr/share/xiboplayer-chromium/configs/apply.sh chromium-sync-lead chromium-sync-lead    PORT=8766
/usr/share/xiboplayer-chromium/configs/apply.sh chromium-sync-follower chromium-sync-follower-1 PORT=8767 TOPOLOGY_X=1

# 3. Start the player
systemctl --user start xiboplayer-chromium

# 4. Clean up an instance
/usr/share/xiboplayer-chromium/configs/clean.sh chromium content   # clear downloaded media only
/usr/share/xiboplayer-chromium/configs/clean.sh chromium browser   # clear browser caches + media
/usr/share/xiboplayer-chromium/configs/clean.sh chromium full      # fresh start, keep auth
/usr/share/xiboplayer-chromium/configs/clean.sh chromium nuke      # total wipe, new display identity
```

### Quick Start (source checkout)

```bash
cd configs/
cp secrets.env.example secrets.env
vi secrets.env
./apply.sh chromium-dev chromium
./clean.sh chromium content
```

### Templates

| Template | Purpose |
|----------|---------|
| `chromium-dev.json` | Development: no kiosk, debug logging, all overlays and controls enabled |
| `chromium-kiosk.json` | Production: kiosk mode, no debug, no controls |
| `chromium-sync-lead.json` | Sync wall leader: 960x540, debug, sync config |
| `chromium-sync-follower.json` | Sync wall follower: configurable port, position, topology |

### Variable Syntax

Templates use `{{VAR}}` and `{{VAR:default}}` placeholders:

```jsonc
{
  "cmsUrl": "{{CMS_URL}}",              // required — error if not in secrets.env or CLI
  "displayName": "{{DISPLAY_NAME:dev}}", // optional — uses "dev" if not provided
  "serverPort": {{PORT:8766}}            // numeric defaults work too
}
```

Variables are resolved in order: CLI args > `secrets.env` > default value.

### Secrets

`~/.config/xiboplayer/secrets.env` holds CMS credentials (per-user, never in system dirs).
The `apply.sh` script looks for secrets here first, falling back to the script's directory:

```bash
CMS_URL=https://your-cms.example.com
CMS_KEY=your-server-key
API_CLIENT_ID=your-oauth-client-id       # optional: enables auto-authorization
API_CLIENT_SECRET=your-oauth-client-secret
```

### Clean Levels

| Level | Removes | Keeps |
|-------|---------|-------|
| `content` | Shared media cache | Browser state, auth, config |
| `browser` | Browser caches + content | Auth (localStorage, IndexedDB), config |
| `full` | Everything except auth | Display identity (hardwareKey, XMR keys) |
| `nuke` | Everything | Nothing — new display, needs re-authorization |
