#!/usr/bin/env bash
# Build xiboplayer-pwa RPM package
# Usage: ./build-rpm.sh [version] [release]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_NAME="xiboplayer-pwa"
VERSION="${1:-1.0.0}"
RELEASE="${2:-1}"

echo "==> Building ${PKG_NAME}-${VERSION}-${RELEASE} RPM"

if ! command -v rpmbuild &>/dev/null; then
    echo "ERROR: rpmbuild not found. Install: sudo dnf install rpm-build"
    exit 1
fi

BUILD_ROOT="${SCRIPT_DIR}/_rpmbuild"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Copy spec with version substitution
sed -e "s/^Version:.*/Version:        ${VERSION}/" \
    -e "s/^Release:.*/Release:        ${RELEASE}%{?dist}/" \
    "$SCRIPT_DIR/xibo-player-pwa.spec" \
    > "$BUILD_ROOT/SPECS/${PKG_NAME}.spec"

# Copy source files (new xiboplayer/ layout)
cp -r "$SCRIPT_DIR/xiboplayer" "$BUILD_ROOT/SOURCES/"

echo "==> Running rpmbuild..."
rpmbuild \
    --define "_topdir $BUILD_ROOT" \
    --define "_sourcedir $BUILD_ROOT/SOURCES" \
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
echo "    Enable:  systemctl --user enable --now xiboplayer-kiosk.service"

rm -rf "$BUILD_ROOT"
