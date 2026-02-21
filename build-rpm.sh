#!/usr/bin/env bash
# Build xiboplayer-chromium RPM package (self-contained with bundled PWA)
# Usage: ./build-rpm.sh [version] [release]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_NAME="xiboplayer-chromium"
VERSION="${1:-0.4.0}"
RELEASE="${2:-1}"

echo "==> Building ${PKG_NAME}-${VERSION}-${RELEASE} RPM (self-contained)"

if ! command -v rpmbuild &>/dev/null; then
    echo "ERROR: rpmbuild not found. Install: sudo dnf install rpm-build"
    exit 1
fi

if ! command -v node &>/dev/null; then
    echo "ERROR: node not found. Install: sudo dnf install nodejs"
    exit 1
fi

BUILD_ROOT="${SCRIPT_DIR}/_rpmbuild"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# --- Create source tarball ---
echo "==> Creating source tarball..."
SRC_DIR="${BUILD_ROOT}/SOURCES/${PKG_NAME}-${VERSION}"
mkdir -p "$SRC_DIR/server"

# Copy source files
cp "$SCRIPT_DIR/xiboplayer/launch-kiosk.sh" "$SRC_DIR/"
cp "$SCRIPT_DIR/xiboplayer/config.json" "$SRC_DIR/"
cp "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.service" "$SRC_DIR/"
cp "$SCRIPT_DIR/xiboplayer/xiboplayer-chromium.desktop" "$SRC_DIR/"
cp "$SCRIPT_DIR/xiboplayer/xiboplayer.png" "$SRC_DIR/"
cp "$SCRIPT_DIR/xiboplayer/server/server.js" "$SRC_DIR/server/"
cp "$SCRIPT_DIR/xiboplayer/server/package.json" "$SRC_DIR/server/"

# Create tarball
cd "${BUILD_ROOT}/SOURCES"
tar czf "${PKG_NAME}-${VERSION}.tar.gz" "${PKG_NAME}-${VERSION}"
rm -rf "${PKG_NAME}-${VERSION}"

# Copy spec with version substitution
sed -e "s/^Version:.*/Version:        ${VERSION}/" \
    -e "s/^Release:.*/Release:        ${RELEASE}%{?dist}/" \
    "$SCRIPT_DIR/xiboplayer-chromium.spec" \
    > "$BUILD_ROOT/SPECS/${PKG_NAME}.spec"

echo "==> Running rpmbuild..."
rpmbuild \
    --define "_topdir $BUILD_ROOT" \
    -bb "$BUILD_ROOT/SPECS/${PKG_NAME}.spec"

# Collect output
DIST_DIR="${SCRIPT_DIR}/dist"
mkdir -p "$DIST_DIR"
find "$BUILD_ROOT/RPMS" -name "*.rpm" -exec cp -v {} "$DIST_DIR/" \;

echo ""
echo "==> Built:"
for rpm in "$DIST_DIR"/*.rpm; do
    [[ -f "$rpm" ]] && echo "    $(basename "$rpm") ($(du -h "$rpm" | cut -f1))"
done
echo "    Install: sudo dnf install ${DIST_DIR}/${PKG_NAME}-${VERSION}-*.noarch.rpm"
echo "    Enable:  systemctl --user enable --now xiboplayer-chromium.service"

rm -rf "$BUILD_ROOT"
