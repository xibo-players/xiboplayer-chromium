#!/usr/bin/env bash
# Build xiboplayer-chromium DEB package (self-contained with bundled PWA)
# Usage: ./build-deb.sh [version] [release]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_NAME="xiboplayer-chromium"
VERSION="${1:-0.5.11}"
RELEASE="${2:-1}"

echo "==> Building ${PKG_NAME}-${VERSION}-${RELEASE} DEB (self-contained)"

if ! command -v dpkg-deb &>/dev/null; then
    echo "ERROR: dpkg-deb not found. Install: sudo apt-get install dpkg-dev"
    exit 1
fi

if ! command -v node &>/dev/null; then
    echo "ERROR: node not found. Install: sudo apt-get install nodejs"
    exit 1
fi

BUILD_ROOT="${SCRIPT_DIR}/_debbuild"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/DEBIAN"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/bin"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/libexec/${PKG_NAME}/server"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/share/${PKG_NAME}"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/lib/systemd/user"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/share/applications"
mkdir -p "$BUILD_ROOT/${PKG_NAME}/usr/share/icons/hicolor/256x256/apps"

# --- Install server + dependencies (fetches @xiboplayer/proxy + @xiboplayer/pwa) ---
echo "==> Installing server dependencies..."
SERVER_DEST="$BUILD_ROOT/${PKG_NAME}/usr/libexec/${PKG_NAME}/server"
install -m755 "$SCRIPT_DIR/xiboplayer/server/server.js" "$SERVER_DEST/"
cp "$SCRIPT_DIR/xiboplayer/server/package.json" "$SERVER_DEST/"
cd "$SERVER_DEST"
npm install --production --no-optional 2>&1
cd "$SCRIPT_DIR"

# --- Install other files ---
echo "==> Installing scripts and config..."
install -m755 "$SCRIPT_DIR/xiboplayer/launch-kiosk.sh" \
    "$BUILD_ROOT/${PKG_NAME}/usr/libexec/${PKG_NAME}/launch-kiosk.sh"

cat > "$BUILD_ROOT/${PKG_NAME}/usr/bin/${PKG_NAME}" << 'EOF'
#!/bin/bash
exec /usr/libexec/xiboplayer-chromium/launch-kiosk.sh "$@"
EOF
chmod 755 "$BUILD_ROOT/${PKG_NAME}/usr/bin/${PKG_NAME}"

install -m644 "$SCRIPT_DIR/xiboplayer/config.json" \
    "$BUILD_ROOT/${PKG_NAME}/usr/share/${PKG_NAME}/config.json.example"

install -m644 "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.service" \
    "$BUILD_ROOT/${PKG_NAME}/usr/lib/systemd/user/${PKG_NAME}.service"

install -m644 "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.desktop" \
    "$BUILD_ROOT/${PKG_NAME}/usr/share/applications/${PKG_NAME}.desktop"

install -m644 "$SCRIPT_DIR/xiboplayer/xiboplayer.png" \
    "$BUILD_ROOT/${PKG_NAME}/usr/share/icons/hicolor/256x256/apps/xiboplayer.png"

echo "==> Creating control file..."
cat > "$BUILD_ROOT/${PKG_NAME}/DEBIAN/control" << EOF
Package: ${PKG_NAME}
Version: ${VERSION}-${RELEASE}
Section: misc
Priority: optional
Architecture: all
Depends: chromium | google-chrome-stable, nodejs (>= 18), jq, curl, systemd
Recommends: x11-xserver-utils, xdotool
Maintainer: Pau Aliagas <linuxnow@gmail.com>
Description: Self-contained Xibo digital signage player (Chromium kiosk)
 Bundles the PWA player locally and serves it via a Node.js server,
 then launches Chromium in kiosk mode. Only the CMS base URL is needed.
Homepage: https://xiboplayer.org
EOF

# postinst — register alternatives
cat > "$BUILD_ROOT/${PKG_NAME}/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
update-alternatives --install /usr/bin/xiboplayer xiboplayer /usr/bin/xiboplayer-chromium 50
EOF
chmod 755 "$BUILD_ROOT/${PKG_NAME}/DEBIAN/postinst"

# prerm — remove alternatives on uninstall
cat > "$BUILD_ROOT/${PKG_NAME}/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e
if [ "$1" = "remove" ]; then
    update-alternatives --remove xiboplayer /usr/bin/xiboplayer-chromium
fi
EOF
chmod 755 "$BUILD_ROOT/${PKG_NAME}/DEBIAN/prerm"

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
echo "    Enable:  systemctl --user enable --now ${PKG_NAME}.service"

rm -rf "$BUILD_ROOT"

# --- Build source package (once, arch-independent) ---
SRC_MARKER="${DIST_DIR}/.source-built"
if [ ! -f "$SRC_MARKER" ]; then
    echo "==> Building source package..."
    SRC_BUILD="${SCRIPT_DIR}/_srcbuild"
    rm -rf "$SRC_BUILD"
    SRC_NAME="${PKG_NAME}-${VERSION}"
    mkdir -p "$SRC_BUILD"

    # Create orig tarball from source files
    ORIG_DIR="$SRC_BUILD/$SRC_NAME"
    mkdir -p "$ORIG_DIR/server"
    cp "$SCRIPT_DIR/xiboplayer/launch-kiosk.sh" "$ORIG_DIR/"
    cp "$SCRIPT_DIR/xiboplayer/config.json" "$ORIG_DIR/"
    cp "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.service" "$ORIG_DIR/"
    cp "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.desktop" "$ORIG_DIR/"
    cp "$SCRIPT_DIR/xiboplayer/xiboplayer.png" "$ORIG_DIR/"
    cp "$SCRIPT_DIR/xiboplayer/server/server.js" "$ORIG_DIR/server/"
    cp "$SCRIPT_DIR/xiboplayer/server/package.json" "$ORIG_DIR/server/"

    cd "$SRC_BUILD"
    tar czf "${PKG_NAME}_${VERSION}.orig.tar.gz" "$SRC_NAME"

    # Create debian/ directory
    mkdir -p "$ORIG_DIR/debian/source"
    echo "3.0 (quilt)" > "$ORIG_DIR/debian/source/format"

    cat > "$ORIG_DIR/debian/control" << EOF
Source: ${PKG_NAME}
Section: misc
Priority: optional
Maintainer: Pau Aliagas <linuxnow@gmail.com>
Build-Depends: debhelper (>= 12), nodejs, npm
Standards-Version: 4.6.0
Homepage: https://xiboplayer.org

Package: ${PKG_NAME}
Architecture: all
Depends: chromium | google-chrome-stable, nodejs (>= 18), jq, curl, systemd
Recommends: x11-xserver-utils, xdotool
Description: Self-contained Xibo digital signage player (Chromium kiosk)
 Bundles the PWA player locally and serves it via a Node.js server,
 then launches Chromium in kiosk mode. Only the CMS base URL is needed.
EOF

    cat > "$ORIG_DIR/debian/changelog" << EOF
${PKG_NAME} (${VERSION}-${RELEASE}) stable; urgency=medium

  * Release ${VERSION}

 -- Pau Aliagas <linuxnow@gmail.com>  $(date -R)
EOF

    cat > "$ORIG_DIR/debian/rules" << 'EOF'
#!/usr/bin/make -f
%:
	dh $@
EOF
    chmod +x "$ORIG_DIR/debian/rules"

    echo "12" > "$ORIG_DIR/debian/compat"

    # Build source package
    cd "$ORIG_DIR"
    dpkg-source -b .
    cd "$SCRIPT_DIR"

    # Copy source package files to output
    cp "$SRC_BUILD"/*.dsc "$DIST_DIR/" 2>/dev/null || true
    cp "$SRC_BUILD"/*.orig.tar.* "$DIST_DIR/" 2>/dev/null || true
    cp "$SRC_BUILD"/*.debian.tar.* "$DIST_DIR/" 2>/dev/null || true

    echo "==> Source package files:"
    ls -lh "$DIST_DIR"/*.dsc "$DIST_DIR"/*.tar.* 2>/dev/null || true

    touch "$SRC_MARKER"
    rm -rf "$SRC_BUILD"
fi
