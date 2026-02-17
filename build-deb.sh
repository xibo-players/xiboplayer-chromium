#!/usr/bin/env bash
# Build xiboplayer-pwa DEB package
# Usage: ./build-deb.sh [version] [release]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_NAME="xiboplayer-pwa"
VERSION="${1:-0.1.0}"
RELEASE="${2:-1}"

echo "==> Building ${PKG_NAME}-${VERSION}-${RELEASE} DEB"

if ! command -v dpkg-deb &>/dev/null; then
    echo "ERROR: dpkg-deb not found. Install: sudo apt-get install dpkg-dev"
    exit 1
fi

BUILD_ROOT="${SCRIPT_DIR}/_debbuild"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/DEBIAN"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/bin"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/libexec/xiboplayer"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/share/xiboplayer"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/lib/systemd/user"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/share/applications"

echo "==> Installing files..."
# Launch script
install -m755 "$SCRIPT_DIR/xiboplayer/launch-kiosk.sh" \
    "$BUILD_ROOT/${PKG_NAME}/usr/libexec/xiboplayer/launch-kiosk.sh"

# Wrapper in PATH
cat > "$BUILD_ROOT/${PKG_NAME}/usr/bin/xiboplayer" << 'EOF'
#!/bin/bash
exec /usr/libexec/xiboplayer/launch-kiosk.sh "$@"
EOF
chmod 755 "$BUILD_ROOT/${PKG_NAME}/usr/bin/xiboplayer"

# Config template
install -m644 "$SCRIPT_DIR/xiboplayer/config.json" \
    "$BUILD_ROOT/${PKG_NAME}/usr/share/xiboplayer/config.json.example"

# Systemd user service
install -m644 "$SCRIPT_DIR/xiboplayer/xiboplayer-kiosk.service" \
    "$BUILD_ROOT/${PKG_NAME}/usr/lib/systemd/user/xiboplayer-kiosk.service"

# Desktop entry
install -m644 "$SCRIPT_DIR/xiboplayer/xiboplayer.desktop" \
    "$BUILD_ROOT/${PKG_NAME}/usr/share/applications/xiboplayer.desktop"

echo "==> Creating control file..."
cat > "$BUILD_ROOT/${PKG_NAME}/DEBIAN/control" << EOF
Package: ${PKG_NAME}
Version: ${VERSION}-${RELEASE}
Section: misc
Priority: optional
Architecture: all
Depends: chromium | google-chrome-stable, jq, xdg-utils, systemd
Recommends: x11-xserver-utils, xdotool
Conflicts: xiboplayer-electron
Maintainer: Pau Aliagas <pau@linuxnow.com>
Description: Xibo PWA digital signage player (browser kiosk)
 Xibo PWA digital signage player for kiosk deployments on Ubuntu.
 Launches a fullscreen browser pointing at a Xibo CMS PWA player URL,
 with automatic restart and screen-blanking prevention.
Homepage: https://github.com/xibo-players/xiboplayer-chromium
EOF

echo "==> Running dpkg-deb..."
dpkg-deb --build "$BUILD_ROOT/${PKG_NAME}" \
    "$BUILD_ROOT/${PKG_NAME}_${VERSION}-${RELEASE}_all.deb"

# Collect output
DIST_DIR="${SCRIPT_DIR}/dist"
mkdir -p "$DIST_DIR"
cp -v "$BUILD_ROOT/${PKG_NAME}_${VERSION}-${RELEASE}_all.deb" "$DIST_DIR/"

echo ""
echo "==> Built:"
for deb in "$DIST_DIR"/*.deb; do
    [[ -f "$deb" ]] && echo "    $(basename "$deb") ($(du -h "$deb" | cut -f1))"
done
echo "    Install: sudo apt install ${DIST_DIR}/${PKG_NAME}_${VERSION}-${RELEASE}_all.deb"
echo "    Enable:  systemctl --user enable --now xiboplayer-kiosk.service"

rm -rf "$BUILD_ROOT"
