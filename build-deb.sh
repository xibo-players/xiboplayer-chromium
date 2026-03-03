#!/usr/bin/env bash
# Build xiboplayer-chromium DEB package (self-contained with bundled PWA)
# Usage: ./build-deb.sh [version] [release]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${PKG_LIB_DEB:-${SCRIPT_DIR}/scripts/packaging/lib-deb.sh}"

# ── Configuration ─────────────────────────────────────────────────────
PKG_NAME="xiboplayer-chromium"
PKG_ARCH="all"
PKG_DEPENDS="chromium | google-chrome-stable, nodejs (>= 18), jq, curl, systemd"
PKG_RECOMMENDS="x11-xserver-utils, xdotool"
PKG_DESCRIPTION="Self-contained Xibo digital signage player (Chromium kiosk)"
PKG_DESCRIPTION_LONG=" Bundles the PWA player locally and serves it via a Node.js server,
 then launches Chromium in kiosk mode. Only the CMS base URL is needed."
PKG_SRC_BUILD_DEPENDS="debhelper (>= 12), nodejs, npm"

ALT_NAME="xiboplayer"
ALT_LINK="/usr/bin/xiboplayer"
ALT_PATH="/usr/bin/xiboplayer-chromium"
ALT_PRIORITY=50

# ── Build ─────────────────────────────────────────────────────────────

if ! command -v dpkg-deb &>/dev/null; then
    echo "ERROR: dpkg-deb not found. Install: sudo apt-get install dpkg-dev"
    exit 1
fi
if ! command -v node &>/dev/null; then
    echo "ERROR: node not found. Install: sudo apt-get install nodejs"
    exit 1
fi

pkg_parse_version "$@"
pkg_create_deb_tree

# ── Chromium-specific: install server + dependencies ──────────────────
echo "==> Installing server dependencies..."
mkdir -p "$PKGDIR/usr/libexec/${PKG_NAME}/server"
SERVER_DEST="$PKGDIR/usr/libexec/${PKG_NAME}/server"
install -m755 "$SCRIPT_DIR/xiboplayer/server/server.js" "$SERVER_DEST/"
cp "$SCRIPT_DIR/xiboplayer/server/package.json" "$SERVER_DEST/"
cd "$SERVER_DEST"
npm install --production --no-optional 2>&1
cd "$SCRIPT_DIR"

echo "==> Installing scripts and config..."
install -m755 "$SCRIPT_DIR/xiboplayer/launch-kiosk.sh" \
    "$PKGDIR/usr/libexec/${PKG_NAME}/launch-kiosk.sh"

cat > "$PKGDIR/usr/bin/${PKG_NAME}" << 'EOF'
#!/bin/bash
exec /usr/libexec/xiboplayer-chromium/launch-kiosk.sh "$@"
EOF
chmod 755 "$PKGDIR/usr/bin/${PKG_NAME}"

mkdir -p "$PKGDIR/usr/share/${PKG_NAME}"
install -m644 "$SCRIPT_DIR/xiboplayer/config.json" \
    "$PKGDIR/usr/share/${PKG_NAME}/config.json"
install -m644 "$SCRIPT_DIR/xiboplayer/config.json.example" \
    "$PKGDIR/usr/share/doc/${PKG_NAME}/config.json.example"
install -m644 "$SCRIPT_DIR/CONFIG.md" \
    "$PKGDIR/usr/share/doc/${PKG_NAME}/CONFIG.md"
install -m644 "$SCRIPT_DIR/README.md" \
    "$PKGDIR/usr/share/doc/${PKG_NAME}/README.md"

install -m644 "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.service" \
    "$PKGDIR/usr/lib/systemd/user/${PKG_NAME}.service"
install -m644 "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.desktop" \
    "$PKGDIR/usr/share/applications/${PKG_NAME}.desktop"
install -m644 "$SCRIPT_DIR/xiboplayer/xiboplayer.png" \
    "$PKGDIR/usr/share/icons/hicolor/256x256/apps/xiboplayer.png"

# ── Package ───────────────────────────────────────────────────────────
pkg_write_control
pkg_write_alternatives
pkg_build_binary_deb
pkg_show_result_deb

# ── Source package ────────────────────────────────────────────────────
populate_chromium_source() {
    local orig_dir="$1"
    mkdir -p "$orig_dir/server"
    cp "$SCRIPT_DIR/xiboplayer/launch-kiosk.sh" "$orig_dir/"
    cp "$SCRIPT_DIR/xiboplayer/config.json" "$orig_dir/"
    cp "$SCRIPT_DIR/xiboplayer/config.json.example" "$orig_dir/"
    cp "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.service" "$orig_dir/"
    cp "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.desktop" "$orig_dir/"
    cp "$SCRIPT_DIR/xiboplayer/xiboplayer.png" "$orig_dir/"
    cp "$SCRIPT_DIR/xiboplayer/server/server.js" "$orig_dir/server/"
    cp "$SCRIPT_DIR/xiboplayer/server/package.json" "$orig_dir/server/"
    cp "$SCRIPT_DIR/CONFIG.md" "$orig_dir/"
    cp "$SCRIPT_DIR/README.md" "$orig_dir/"
}

pkg_build_source_deb populate_chromium_source
