#!/usr/bin/env bash
# =============================================================================
# Xibo PWA Player — Kiosk Launcher
#
# Reads configuration from /etc/xibo-player/config.env and launches a
# fullscreen browser in kiosk mode pointing at the configured CMS URL.
#
# Supports both Chromium/Chrome and Firefox.
# Handles screen-blanking prevention for X11 and Wayland (GNOME / KDE).
# =============================================================================

set -euo pipefail

CONFIG_FILE="/etc/xibo-player/config.env"
LOCK_FILE="/tmp/xibo-player-kiosk.lock"

# ---------------------------------------------------------------------------
# Defaults (overridden by config.env)
# ---------------------------------------------------------------------------
CMS_URL="https://your-cms.example.com:8081/player/pwa/"
BROWSER="chromium"
DISPLAY_KEY=""
EXTRA_BROWSER_FLAGS=""

# ---------------------------------------------------------------------------
# Load configuration
# ---------------------------------------------------------------------------
if [[ -f "$CONFIG_FILE" ]]; then
    # Source only KEY=VALUE lines, ignoring comments and empty lines
    set -a
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    set +a
else
    echo "[xibo-player] WARNING: Config file $CONFIG_FILE not found, using defaults." >&2
fi

# Append display key to URL if set
PLAYER_URL="$CMS_URL"
if [[ -n "$DISPLAY_KEY" ]]; then
    # Add as query parameter
    if [[ "$PLAYER_URL" == *"?"* ]]; then
        PLAYER_URL="${PLAYER_URL}&displayKey=${DISPLAY_KEY}"
    else
        PLAYER_URL="${PLAYER_URL}?displayKey=${DISPLAY_KEY}"
    fi
fi

# ---------------------------------------------------------------------------
# Locking — prevent duplicate instances
# ---------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    echo "[xibo-player] Shutting down (exit code: $exit_code)..." >&2
    rm -f "$LOCK_FILE"
    restore_screen_blanking
    # Kill any child browser processes in our process group
    kill -- -$$ 2>/dev/null || true
    exit "$exit_code"
}

if [[ -f "$LOCK_FILE" ]]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[xibo-player] Already running (PID $OLD_PID). Exiting." >&2
        exit 1
    fi
    echo "[xibo-player] Stale lock file found, removing." >&2
    rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"
trap cleanup EXIT INT TERM HUP

# ---------------------------------------------------------------------------
# Disable screen blanking / DPMS
# ---------------------------------------------------------------------------
disable_screen_blanking() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        # GNOME on Wayland
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
            gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true
            gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>/dev/null || true
            echo "[xibo-player] Disabled GNOME screen blanking (Wayland)." >&2
        fi
        # KDE on Wayland
        if command -v kwriteconfig5 &>/dev/null; then
            kwriteconfig5 --file powermanagementprofilesrc \
                --group AC --group DPMSControl --key idleTime 0 2>/dev/null || true
            echo "[xibo-player] Disabled KDE screen blanking (Wayland)." >&2
        fi
    fi

    if [[ -n "${DISPLAY:-}" ]]; then
        # X11: use xset to disable screen saver and DPMS
        if command -v xset &>/dev/null; then
            xset s off 2>/dev/null || true
            xset s noblank 2>/dev/null || true
            xset -dpms 2>/dev/null || true
            echo "[xibo-player] Disabled X11 screen blanking (xset)." >&2
        fi
    fi
}

restore_screen_blanking() {
    # Restore DPMS defaults on exit (optional, kiosk usually stays running)
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
        firefox)
            if command -v firefox &>/dev/null; then
                echo "firefox"
                return
            fi
            ;;
        *)
            # Treat as literal binary name
            if command -v "$browser_lower" &>/dev/null; then
                echo "$browser_lower"
                return
            fi
            ;;
    esac

    echo ""
}

# ---------------------------------------------------------------------------
# Build browser arguments
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

    # User data directory to keep profile isolated
    args+=(--user-data-dir=/opt/xibo-player/.chromium-profile)

    # Append any user-defined extra flags
    if [[ -n "$EXTRA_BROWSER_FLAGS" ]]; then
        # Split extra flags by space (allows quoted values in config.env)
        read -ra extra <<< "$EXTRA_BROWSER_FLAGS"
        args+=("${extra[@]}")
    fi

    # URL must be last
    args+=("$PLAYER_URL")

    echo "${args[@]}"
}

build_firefox_args() {
    local -a args=(
        --kiosk
        --no-remote
    )

    # Dedicated profile directory
    args+=(--profile /opt/xibo-player/.firefox-profile)

    # Append any user-defined extra flags
    if [[ -n "$EXTRA_BROWSER_FLAGS" ]]; then
        read -ra extra <<< "$EXTRA_BROWSER_FLAGS"
        args+=("${extra[@]}")
    fi

    # URL must be last
    args+=("$PLAYER_URL")

    echo "${args[@]}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo "[xibo-player] Starting Xibo PWA Kiosk Player" >&2
    echo "[xibo-player]   URL:     $PLAYER_URL" >&2
    echo "[xibo-player]   Browser: $BROWSER" >&2

    # Wait for display to be available (important for systemd startup)
    local retries=0
    while [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && (( retries < 30 )); do
        echo "[xibo-player] Waiting for display server... (attempt $((retries+1))/30)" >&2
        sleep 2
        retries=$((retries + 1))
    done

    if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
        echo "[xibo-player] ERROR: No display server available after 60 seconds." >&2
        exit 1
    fi

    # Disable screen blanking
    disable_screen_blanking

    # Resolve browser binary
    local browser_bin
    browser_bin=$(resolve_browser)
    if [[ -z "$browser_bin" ]]; then
        echo "[xibo-player] ERROR: Browser '$BROWSER' not found." >&2
        echo "[xibo-player]   Install it with: sudo dnf install chromium" >&2
        exit 1
    fi
    echo "[xibo-player]   Binary:  $browser_bin" >&2

    # Create profile directories
    mkdir -p /opt/xibo-player/.chromium-profile 2>/dev/null || true
    mkdir -p /opt/xibo-player/.firefox-profile 2>/dev/null || true

    # Build arguments and launch
    local args
    local browser_lower
    browser_lower=$(echo "$BROWSER" | tr '[:upper:]' '[:lower:]')

    case "$browser_lower" in
        firefox)
            args=$(build_firefox_args)
            ;;
        *)
            args=$(build_chromium_args)
            ;;
    esac

    echo "[xibo-player]   Args:    $args" >&2
    echo "[xibo-player] Launching browser..." >&2

    # Execute the browser — this blocks until the browser exits.
    # shellcheck disable=SC2086
    exec "$browser_bin" $args
}

main "$@"
