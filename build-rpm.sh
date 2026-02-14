#!/usr/bin/env bash
# =============================================================================
# Build RPM package for xibo-player-pwa
#
# Usage:
#   ./build-rpm.sh              Build with default version (1.0.0)
#   ./build-rpm.sh 2.1.0        Build with custom version
#   ./build-rpm.sh 1.0.0 2      Build with custom version and release number
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_NAME="xibo-player-pwa"
VERSION="${1:-1.0.0}"
RELEASE="${2:-1}"

echo "============================================================"
echo "  Building ${PKG_NAME}-${VERSION}-${RELEASE} RPM"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
for cmd in rpmbuild; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' not found. Install with:"
        echo "  sudo dnf install rpm-build rpmdevtools"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Setup rpmbuild directory structure
# ---------------------------------------------------------------------------
BUILD_ROOT="${SCRIPT_DIR}/_rpmbuild"
rm -rf "$BUILD_ROOT"

mkdir -p "$BUILD_ROOT"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "[1/4] Copying spec file..."
# Update version in spec file
sed -e "s/^Version:.*/Version:        ${VERSION}/" \
    -e "s/^Release:.*/Release:        ${RELEASE}%{?dist}/" \
    "$SCRIPT_DIR/xibo-player-pwa.spec" \
    > "$BUILD_ROOT/SPECS/${PKG_NAME}.spec"

echo "[2/4] Copying source files..."
# Copy source files into SOURCES (the spec references them with %{_sourcedir})
cp -r "$SCRIPT_DIR/opt" "$BUILD_ROOT/SOURCES/"
cp -r "$SCRIPT_DIR/etc" "$BUILD_ROOT/SOURCES/"
mkdir -p "$BUILD_ROOT/SOURCES/usr/lib/systemd/user"
cp "$SCRIPT_DIR/usr/lib/systemd/user/xibo-player-kiosk.service" \
   "$BUILD_ROOT/SOURCES/usr/lib/systemd/user/"
mkdir -p "$BUILD_ROOT/SOURCES/usr/share/applications"
cp "$SCRIPT_DIR/usr/share/applications/xibo-player.desktop" \
   "$BUILD_ROOT/SOURCES/usr/share/applications/"

echo "[3/4] Building RPM..."
rpmbuild \
    --define "_topdir $BUILD_ROOT" \
    --define "_sourcedir $BUILD_ROOT/SOURCES" \
    -bb "$BUILD_ROOT/SPECS/${PKG_NAME}.spec"

# ---------------------------------------------------------------------------
# Collect output
# ---------------------------------------------------------------------------
DIST_DIR="${SCRIPT_DIR}/dist"
mkdir -p "$DIST_DIR"

echo "[4/4] Collecting RPM output..."
find "$BUILD_ROOT/RPMS" -name "*.rpm" -exec cp -v {} "$DIST_DIR/" \;

echo ""
echo "============================================================"
echo "  Build complete!"
echo ""
echo "  RPM files:"
for rpm in "$DIST_DIR"/*.rpm; do
    if [[ -f "$rpm" ]]; then
        echo "    $(basename "$rpm")  ($(du -h "$rpm" | cut -f1))"
    fi
done
echo ""
echo "  Install with:"
echo "    sudo dnf install ${DIST_DIR}/${PKG_NAME}-${VERSION}-*.noarch.rpm"
echo "============================================================"

# ---------------------------------------------------------------------------
# Cleanup build artifacts (keep dist/)
# ---------------------------------------------------------------------------
rm -rf "$BUILD_ROOT"
echo ""
echo "Build directory cleaned up."
