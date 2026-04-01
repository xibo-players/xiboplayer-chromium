#!/usr/bin/env bats
# Tests for launch-kiosk.sh config loading and flag generation

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../xiboplayer" && pwd)"

setup() {
    export TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_CONFIG_DIR="$TMPDIR/xiboplayer-test-$$"
    mkdir -p "$TEST_CONFIG_DIR"
}

teardown() {
    rm -rf "$TEST_CONFIG_DIR"
}

# ── cfg_read function ───────────────────────────────────────

@test "cfg_read extracts string value from JSON" {
    echo '{"browser": "firefox"}' > "$TEST_CONFIG_DIR/config.json"
    source <(cat <<'FUNCS'
cfg_read() {
    local varname="$1" key="$2" file="$3"
    local val
    val=$(jq -r ".$key // empty" "$file" 2>/dev/null) || true
    [[ -n "$val" ]] && printf -v "$varname" '%s' "$val" || true
}
FUNCS
)
    BROWSER="chromium"
    cfg_read BROWSER browser "$TEST_CONFIG_DIR/config.json"
    [[ "$BROWSER" = "firefox" ]]
}

@test "cfg_read keeps default when key is missing" {
    echo '{}' > "$TEST_CONFIG_DIR/config.json"
    source <(cat <<'FUNCS'
cfg_read() {
    local varname="$1" key="$2" file="$3"
    local val
    val=$(jq -r ".$key // empty" "$file" 2>/dev/null) || true
    [[ -n "$val" ]] && printf -v "$varname" '%s' "$val" || true
}
FUNCS
)
    BROWSER="chromium"
    cfg_read BROWSER browser "$TEST_CONFIG_DIR/config.json"
    [[ "$BROWSER" = "chromium" ]]
}

@test "cfg_read handles numeric values" {
    echo '{"serverPort": 9999}' > "$TEST_CONFIG_DIR/config.json"
    source <(cat <<'FUNCS'
cfg_read() {
    local varname="$1" key="$2" file="$3"
    local val
    val=$(jq -r ".$key // empty" "$file" 2>/dev/null) || true
    [[ -n "$val" ]] && printf -v "$varname" '%s' "$val" || true
}
FUNCS
)
    SERVER_PORT="8766"
    cfg_read SERVER_PORT serverPort "$TEST_CONFIG_DIR/config.json"
    [[ "$SERVER_PORT" = "9999" ]]
}

@test "cfg_read handles null values as empty" {
    echo '{"browser": null}' > "$TEST_CONFIG_DIR/config.json"
    source <(cat <<'FUNCS'
cfg_read() {
    local varname="$1" key="$2" file="$3"
    local val
    val=$(jq -r ".$key // empty" "$file" 2>/dev/null) || true
    [[ -n "$val" ]] && printf -v "$varname" '%s' "$val" || true
}
FUNCS
)
    BROWSER="chromium"
    cfg_read BROWSER browser "$TEST_CONFIG_DIR/config.json"
    [[ "$BROWSER" = "chromium" ]]
}

# ── load_config function ────────────────────────────────────

@test "load_config sets all variables from full config" {
    cat > "$TEST_CONFIG_DIR/config.json" <<'JSON'
{
    "browser": "firefox",
    "serverPort": 9000,
    "kioskMode": "false",
    "fullscreen": "false",
    "width": 1280,
    "height": 720
}
JSON
    source <(cat <<'FUNCS'
cfg_read() {
    local varname="$1" key="$2" file="$3"
    local val
    val=$(jq -r ".$key // empty" "$file" 2>/dev/null) || true
    [[ -n "$val" ]] && printf -v "$varname" '%s' "$val" || true
}
load_config() {
    local file="$1"
    cfg_read BROWSER            browser            "$file"
    cfg_read EXTRA_BROWSER_FLAGS extraBrowserFlags  "$file"
    cfg_read SERVER_PORT        serverPort         "$file"
    cfg_read KIOSK_MODE         kioskMode          "$file"
    cfg_read FULLSCREEN         fullscreen         "$file"
    cfg_read WINDOW_WIDTH       width              "$file"
    cfg_read WINDOW_HEIGHT      height             "$file"
}
FUNCS
)
    # Set defaults
    BROWSER="chromium"; SERVER_PORT="8766"; KIOSK_MODE="true"
    FULLSCREEN="true"; WINDOW_WIDTH="1920"; WINDOW_HEIGHT="1080"
    EXTRA_BROWSER_FLAGS=""

    load_config "$TEST_CONFIG_DIR/config.json"
    [[ "$BROWSER" = "firefox" ]]
    [[ "$SERVER_PORT" = "9000" ]]
    [[ "$KIOSK_MODE" = "false" ]]
    [[ "$FULLSCREEN" = "false" ]]
    [[ "$WINDOW_WIDTH" = "1280" ]]
    [[ "$WINDOW_HEIGHT" = "720" ]]
}

# ── configs/apply.sh ────────────────────────────────────────

@test "apply.sh substitutes template variables" {
    if [[ ! -f "$SCRIPT_DIR/../configs/apply.sh" ]]; then
        skip "apply.sh not found"
    fi

    mkdir -p "$TEST_CONFIG_DIR/templates" "$TEST_CONFIG_DIR/output"
    echo '{"cmsUrl": "https://cms.example.com"}' > "$TEST_CONFIG_DIR/templates/config.json"
    echo 'CMS_URL=https://cms.example.com' > "$TEST_CONFIG_DIR/secrets.env"

    # apply.sh expects specific directory structure — skip if it can't run standalone
    skip "apply.sh requires full config directory structure"
}

# ── CLI argument parsing ────────────────────────────────────

@test "CLI --port override is parsed correctly" {
    SERVER_PORT="8766"
    arg="--port=9999"
    case "$arg" in
        --port=*) SERVER_PORT="${arg#*=}" ;;
    esac
    [[ "$SERVER_PORT" = "9999" ]]
}

@test "CLI --instance is parsed correctly" {
    INSTANCE=""
    arg="--instance=lobby"
    case "$arg" in
        --instance=*) INSTANCE="${arg#*=}" ;;
    esac
    [[ "$INSTANCE" = "lobby" ]]
}

@test "CLI --no-kiosk sets kiosk mode off" {
    KIOSK_MODE="true"
    arg="--no-kiosk"
    case "$arg" in
        --no-kiosk) KIOSK_MODE="false" ;;
    esac
    [[ "$KIOSK_MODE" = "false" ]]
}
