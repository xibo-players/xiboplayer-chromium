# Xibo PWA Player -- Fedora RPM Package

RPM distribution of the Xibo PWA digital signage player for kiosk deployments on Fedora, RHEL, and CentOS Stream.

## What It Does

- Launches a fullscreen browser in kiosk mode pointed at your Xibo CMS PWA player URL
- Auto-restarts the browser if it crashes
- Disables screen blanking and DPMS (X11 and Wayland)
- Starts automatically on user login via a systemd user service

## Building the RPM

### Prerequisites

```bash
sudo dnf install rpm-build rpmdevtools
```

### Build

```bash
cd platforms/fedora-rpm
chmod +x build-rpm.sh
./build-rpm.sh
```

The RPM is output to `dist/xibo-player-pwa-1.0.0-1.fc*.noarch.rpm`.

To build with a custom version:

```bash
./build-rpm.sh 2.0.0        # Version 2.0.0, release 1
./build-rpm.sh 2.0.0 3      # Version 2.0.0, release 3
```

## Installation

### From local build

```bash
sudo dnf install dist/xibo-player-pwa-1.0.0-1.fc*.noarch.rpm
```

### From GitHub release

```bash
# Download the latest release RPM, then:
sudo dnf install ./xibo-player-pwa-*.noarch.rpm
```

`dnf` will automatically pull in `chromium` if no supported browser is installed.

## Configuration

Edit the configuration file:

```bash
sudo nano /etc/xibo-player/config.env
```

### Required settings

| Variable | Description | Example |
|----------|-------------|---------|
| `CMS_URL` | Full URL to your Xibo CMS PWA player | `https://h1.superpantalles.com:8081/player/pwa/` |

### Optional settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BROWSER` | `chromium` | Browser to use: `chromium`, `chrome`, `google-chrome-stable`, `firefox` |
| `DISPLAY_KEY` | *(empty)* | Override the auto-generated hardware key |
| `EXTRA_BROWSER_FLAGS` | *(empty)* | Additional browser command-line flags |

### Example configuration

```bash
CMS_URL=https://h1.superpantalles.com:8081/player/pwa/
BROWSER=chromium
DISPLAY_KEY=
EXTRA_BROWSER_FLAGS=--force-device-scale-factor=1
```

## Enabling Kiosk Auto-Start

The kiosk runs as a **systemd user service**, meaning it runs as the logged-in desktop user (not root).

### Enable (run as the kiosk user, not root)

```bash
systemctl --user enable --now xibo-player-kiosk.service
```

### Disable

```bash
systemctl --user disable --now xibo-player-kiosk.service
```

### Check status

```bash
systemctl --user status xibo-player-kiosk.service
```

### View logs

```bash
journalctl --user -u xibo-player-kiosk.service -f
```

### Manual launch (for testing)

```bash
/opt/xibo-player/launch-kiosk.sh
```

## Auto-Login Setup (Kiosk Machines)

For a true kiosk that boots directly into the player, configure auto-login for the kiosk user.

### GNOME (GDM)

Edit `/etc/gdm/custom.conf`:

```ini
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=kiosk
```

### Create a dedicated kiosk user

```bash
sudo useradd -m -s /bin/bash kiosk
sudo passwd kiosk

# Enable the service for that user
sudo -u kiosk bash -c 'systemctl --user enable xibo-player-kiosk.service'

# Enable lingering so user services start at boot (before login)
sudo loginctl enable-linger kiosk
```

## Troubleshooting

### Screen goes blank after inactivity

The launch script disables screen blanking, but some desktop environments override this. Verify:

**X11:**

```bash
xset q | grep -A2 "Screen Saver"
# Should show: timeout 0, cycle 0
xset q | grep -A2 DPMS
# Should show: DPMS is Disabled
```

**GNOME (Wayland or X11):**

```bash
gsettings get org.gnome.desktop.session idle-delay
# Should be: uint32 0
gsettings get org.gnome.desktop.screensaver lock-enabled
# Should be: false
```

If blanking persists, set manually:

```bash
# X11
xset s off && xset s noblank && xset -dpms

# GNOME
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
```

### No audio output

Chromium may need PulseAudio or PipeWire. Ensure audio is configured:

```bash
# Check PipeWire/PulseAudio
pactl info

# Grant audio access if using a restricted user
sudo usermod -aG audio kiosk
```

### Browser shows "Your connection is not private"

If your CMS uses a self-signed certificate:

```bash
# Option 1: Add certificate to system trust store
sudo cp your-cert.pem /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# Option 2: Use browser flag (less secure)
EXTRA_BROWSER_FLAGS=--ignore-certificate-errors
```

### Service fails to start

Check that a graphical session is available:

```bash
echo $DISPLAY $WAYLAND_DISPLAY
# Should show :0 or wayland-0
```

If running headless or via SSH, the service cannot start (it needs a display server).

### Browser opens but not in fullscreen

Some window managers intercept fullscreen. Try adding:

```bash
EXTRA_BROWSER_FLAGS=--start-fullscreen --window-size=1920,1080
```

### Multiple instances / lock file error

If the player reports "Already running", clean up the lock:

```bash
rm -f /tmp/xibo-player-kiosk.lock
```

### Using Google Chrome instead of Chromium

```bash
sudo dnf install google-chrome-stable
# Then in /etc/xibo-player/config.env:
BROWSER=google-chrome-stable
```

### Using Firefox

```bash
# In /etc/xibo-player/config.env:
BROWSER=firefox
```

Note: Firefox kiosk mode (`--kiosk`) is supported since Firefox 71.

## Uninstalling

```bash
sudo dnf remove xibo-player-pwa
```

This removes the scripts and service file. The configuration in `/etc/xibo-player/config.env` is preserved (marked `%config(noreplace)` in the spec).

To fully remove everything:

```bash
sudo dnf remove xibo-player-pwa
sudo rm -rf /etc/xibo-player /opt/xibo-player
```

## Files Installed

| Path | Purpose |
|------|---------|
| `/opt/xibo-player/launch-kiosk.sh` | Main launch script |
| `/etc/xibo-player/config.env` | Configuration (preserved on upgrade) |
| `/usr/lib/systemd/user/xibo-player-kiosk.service` | Systemd user service |
| `/usr/share/applications/xibo-player.desktop` | Desktop entry for manual launch |

## CI/CD

The GitHub Actions workflow (`.github/workflows/build-rpm.yml`) automatically:

1. Builds the RPM on push to the `deploy` branch (when `platforms/fedora-rpm/` files change)
2. Uploads the RPM as a build artifact
3. Creates a GitHub release with the RPM attached when a `rpm-v*` tag is pushed

### Creating a release

```bash
git tag rpm-v1.0.0
git push origin rpm-v1.0.0
```

## License

AGPLv3 -- See [LICENSE](../../LICENSE) for details.
