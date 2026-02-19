#!/usr/bin/env bash
# =============================================================================
# Xibo Player — Self-contained Chromium Kiosk
#
# Starts a local Node.js server that serves the bundled PWA player and proxies
# CMS API requests, then launches Chromium in kiosk mode pointing at localhost.
#
# The PWA player files and server are bundled in the RPM — no external PWA
# server is needed. Only the CMS base URL is required in the config.
# =============================================================================

set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xiboplayer"
CONFIG_FILE="${CONFIG_DIR}/config.json"
LOCK_FILE="/tmp/xiboplayer-kiosk.lock"
SERVER_PID_FILE="/tmp/xiboplayer-server.pid"

# Installed paths (RPM/DEB layout)
SERVER_DIR="/usr/libexec/xiboplayer-chromium/server"

# Server defaults
SERVER_PORT=8765
PLAYER_URL="http://localhost:${SERVER_PORT}/player/pwa/"

# ---------------------------------------------------------------------------
# Defaults (overridden by config.json)
# ---------------------------------------------------------------------------
CMS_URL=""
BROWSER="chromium"
DISPLAY_KEY=""
EXTRA_BROWSER_FLAGS=""

# ---------------------------------------------------------------------------
# Load configuration (JSON via jq)
# ---------------------------------------------------------------------------
if ! command -v jq &>/dev/null; then
    echo "[xiboplayer] ERROR: jq is required. Install: sudo dnf install jq" >&2
    exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
    CMS_URL=$(jq -r '.cmsUrl // empty' "$CONFIG_FILE" 2>/dev/null) || true
    BROWSER=$(jq -r '.browser // "chromium"' "$CONFIG_FILE" 2>/dev/null) || true
    DISPLAY_KEY=$(jq -r '.displayKey // empty' "$CONFIG_FILE" 2>/dev/null) || true
    EXTRA_BROWSER_FLAGS=$(jq -r '.extraBrowserFlags // empty' "$CONFIG_FILE" 2>/dev/null) || true
else
    # First run — create default config from template
    mkdir -p "$CONFIG_DIR"
    if [[ -f /usr/share/xiboplayer-chromium/config.json.example ]]; then
        cp /usr/share/xiboplayer-chromium/config.json.example "$CONFIG_FILE"
        echo "[xiboplayer] Created default config at $CONFIG_FILE — edit cmsUrl and restart." >&2
        exit 0
    else
        echo "[xiboplayer] ERROR: No config at $CONFIG_FILE and no template found." >&2
        exit 1
    fi
fi

if [[ -z "$CMS_URL" || "$CMS_URL" == "https://your-cms.example.com" ]]; then
    echo "[xiboplayer] ERROR: cmsUrl not configured." >&2
    echo "[xiboplayer]   Edit $CONFIG_FILE and set cmsUrl to your CMS address." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Locking — prevent duplicate instances
# ---------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    echo "[xiboplayer] Shutting down (exit code: $exit_code)..." >&2
    # Stop the local server
    if [[ -f "$SERVER_PID_FILE" ]]; then
        local srv_pid
        srv_pid=$(cat "$SERVER_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$srv_pid" ]] && kill -0 "$srv_pid" 2>/dev/null; then
            kill "$srv_pid" 2>/dev/null || true
            echo "[xiboplayer] Stopped local server (PID $srv_pid)." >&2
        fi
        rm -f "$SERVER_PID_FILE"
    fi
    rm -f "$LOCK_FILE"
    restore_screen_blanking
    # Kill any child processes in our process group
    kill -- -$$ 2>/dev/null || true
    exit "$exit_code"
}

if [[ -f "$LOCK_FILE" ]]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[xiboplayer] Already running (PID $OLD_PID). Exiting." >&2
        exit 1
    fi
    echo "[xiboplayer] Stale lock file found, removing." >&2
    rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"
trap cleanup EXIT INT TERM HUP

# ---------------------------------------------------------------------------
# Disable screen blanking / DPMS
# ---------------------------------------------------------------------------
disable_screen_blanking() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
            gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true
            gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>/dev/null || true
            echo "[xiboplayer] Disabled GNOME screen blanking (Wayland)." >&2
        fi
        if command -v kwriteconfig5 &>/dev/null; then
            kwriteconfig5 --file powermanagementprofilesrc \
                --group AC --group DPMSControl --key idleTime 0 2>/dev/null || true
            echo "[xiboplayer] Disabled KDE screen blanking (Wayland)." >&2
        fi
    fi

    if [[ -n "${DISPLAY:-}" ]]; then
        if command -v xset &>/dev/null; then
            xset s off 2>/dev/null || true
            xset s noblank 2>/dev/null || true
            xset -dpms 2>/dev/null || true
            echo "[xiboplayer] Disabled X11 screen blanking (xset)." >&2
        fi
    fi
}

restore_screen_blanking() {
    if [[ -n "${DISPLAY:-}" ]] && command -v xset &>/dev/null; then
        xset +dpms 2>/dev/null || true
        xset s on 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Resolve browser binary
# ---------------------------------------------------------------------------
resolve_browser() {
    local browser_lower
    browser_lower=$(echo "$BROWSER" | tr '[:upper:]' '[:lower:]')

    case "$browser_lower" in
        chromium|chromium-browser)
            for bin in chromium-browser chromium; do
                if command -v "$bin" &>/dev/null; then
                    echo "$bin"
                    return
                fi
            done
            ;;
        chrome|google-chrome|google-chrome-stable)
            for bin in google-chrome-stable google-chrome chrome; do
                if command -v "$bin" &>/dev/null; then
                    echo "$bin"
                    return
                fi
            done
            ;;
        *)
            if command -v "$browser_lower" &>/dev/null; then
                echo "$browser_lower"
                return
            fi
            ;;
    esac

    echo ""
}

# ---------------------------------------------------------------------------
# Start local server
# ---------------------------------------------------------------------------
start_server() {
    if ! command -v node &>/dev/null; then
        echo "[xiboplayer] ERROR: Node.js is required. Install: sudo dnf install nodejs" >&2
        exit 1
    fi

    echo "[xiboplayer] Starting local server on port $SERVER_PORT..." >&2
    node "$SERVER_DIR/server.js" --port="$SERVER_PORT" &
    local srv_pid=$!
    echo "$srv_pid" > "$SERVER_PID_FILE"

    # Wait for server to be ready (up to 10 seconds)
    local retries=0
    while (( retries < 50 )); do
        if curl -s -o /dev/null "http://localhost:${SERVER_PORT}/" 2>/dev/null; then
            echo "[xiboplayer] Server ready (PID $srv_pid)." >&2
            return 0
        fi
        # Check if server process died
        if ! kill -0 "$srv_pid" 2>/dev/null; then
            echo "[xiboplayer] ERROR: Server process died." >&2
            return 1
        fi
        sleep 0.2
        retries=$((retries + 1))
    done

    echo "[xiboplayer] ERROR: Server did not start within 10 seconds." >&2
    kill "$srv_pid" 2>/dev/null || true
    return 1
}

# ---------------------------------------------------------------------------
# Build Chromium arguments
# ---------------------------------------------------------------------------
build_chromium_args() {
    local -a args=(
        --kiosk
        --no-first-run
        --disable-translate
        --disable-infobars
        --disable-suggestions-service
        --disable-save-password-bubble
        --disable-session-crashed-bubble
        --disable-component-update
        --noerrdialogs
        --disable-pinch
        --overscroll-history-navigation=0
        --autoplay-policy=no-user-gesture-required
        --check-for-update-interval=31536000
        --disable-features=TranslateUI
        --disable-ipc-flooding-protection
        --password-store=basic
    )

    # XDG-compliant profile directory
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/xiboplayer"
    args+=(--user-data-dir="$data_dir/chromium-profile")

    # Append any user-defined extra flags
    if [[ -n "$EXTRA_BROWSER_FLAGS" ]]; then
        read -ra extra <<< "$EXTRA_BROWSER_FLAGS"
        args+=("${extra[@]}")
    fi

    # URL must be last — point at local server, not remote CMS
    args+=("$PLAYER_URL")

    echo "${args[@]}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo "[xiboplayer] Starting Xibo Player (self-contained)" >&2
    echo "[xiboplayer]   CMS:     $CMS_URL" >&2
    echo "[xiboplayer]   Browser: $BROWSER" >&2
    echo "[xiboplayer]   Server:  http://localhost:$SERVER_PORT" >&2

    # Wait for display to be available (important for systemd startup)
    local retries=0
    while [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && (( retries < 30 )); do
        echo "[xiboplayer] Waiting for display server... (attempt $((retries+1))/30)" >&2
        sleep 2
        retries=$((retries + 1))
    done

    if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
        echo "[xiboplayer] ERROR: No display server available after 60 seconds." >&2
        exit 1
    fi

    # Disable screen blanking
    disable_screen_blanking

    # Start the local server (serves PWA + proxies CMS)
    start_server || exit 1

    # Resolve browser binary
    local browser_bin
    browser_bin=$(resolve_browser)
    if [[ -z "$browser_bin" ]]; then
        echo "[xiboplayer] ERROR: Browser '$BROWSER' not found." >&2
        echo "[xiboplayer]   Install: sudo dnf install chromium" >&2
        exit 1
    fi
    echo "[xiboplayer]   Binary:  $browser_bin" >&2

    # Create profile directory
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/xiboplayer"
    mkdir -p "$data_dir/chromium-profile" 2>/dev/null || true

    # Build arguments and launch
    local args
    args=$(build_chromium_args)

    echo "[xiboplayer]   Args:    $args" >&2
    echo "[xiboplayer] Launching browser..." >&2

    # Execute the browser — this blocks until the browser exits.
    # shellcheck disable=SC2086
    "$browser_bin" $args
}

main "$@"
