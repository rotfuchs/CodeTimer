#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$ROOT_DIR/neutralino.config.json"
DIST_DIR="$ROOT_DIR/dist/CodeTimer"
README_SOURCE="$ROOT_DIR/README.md"
LICENSE_SOURCE="$ROOT_DIR/LICENSE"
PACKAGE_NAME="codetimer"
ARCH_INPUT="${1:-x64}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

optional_command() {
    command -v "$1" >/dev/null 2>&1
}

json_value() {
    local key="$1"
    sed -n "s/.*\"$key\": \"\\([^\"]*\\)\".*/\\1/p" "$CONFIG_FILE" | head -n 1
}

map_architecture() {
    case "$1" in
        x64) echo "amd64" ;;
        arm64) echo "arm64" ;;
        armhf) echo "armhf" ;;
        *)
            echo "Unsupported architecture: $1" >&2
            echo "Use one of: x64, arm64, armhf" >&2
            exit 1
            ;;
    esac
}

require_command dpkg-deb
require_command gzip

APP_NAME="$(json_value "binaryName")"
VERSION="$(json_value "version")"
PACKAGE_ARCH="$(map_architecture "$ARCH_INPUT")"
BIN_NAME="$APP_NAME-linux_$ARCH_INPUT"
BIN_SOURCE="$DIST_DIR/$BIN_NAME"
RESOURCES_SOURCE="$DIST_DIR/resources.neu"
ICON_SOURCE="$ROOT_DIR/resources/icons/appicon.png"
SVG_ICON_SOURCE="$ROOT_DIR/resources/icons/codetimer_icon.svg"
PKG_ROOT="$ROOT_DIR/dist/deb/${PACKAGE_NAME}_${VERSION}_${PACKAGE_ARCH}"
INSTALL_DIR="$PKG_ROOT/opt/$PACKAGE_NAME"
CONTROL_DIR="$PKG_ROOT/DEBIAN"
DESKTOP_DIR="$PKG_ROOT/usr/share/applications"
PNG_ICON_DIR="$PKG_ROOT/usr/share/icons/hicolor/200x200/apps"
SVG_ICON_DIR="$PKG_ROOT/usr/share/icons/hicolor/scalable/apps"
BIN_LINK_DIR="$PKG_ROOT/usr/bin"
DOC_DIR="$PKG_ROOT/usr/share/doc/$PACKAGE_NAME"
OUTPUT_DEB="$ROOT_DIR/dist/deb/${PACKAGE_NAME}_${VERSION}_${PACKAGE_ARCH}.deb"
MAINTAINER="${DEB_MAINTAINER:-CodeTimer Maintainer <maintainer@example.com>}"

if [[ ! -f "$BIN_SOURCE" ]]; then
    echo "Missing binary: $BIN_SOURCE" >&2
    echo "Run 'neu build' first." >&2
    exit 1
fi

if [[ ! -f "$RESOURCES_SOURCE" ]]; then
    echo "Missing resources archive: $RESOURCES_SOURCE" >&2
    echo "Run 'neu build' first." >&2
    exit 1
fi

if [[ ! -f "$README_SOURCE" ]]; then
    echo "Missing README: $README_SOURCE" >&2
    exit 1
fi

if [[ ! -f "$LICENSE_SOURCE" ]]; then
    echo "Missing license: $LICENSE_SOURCE" >&2
    exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "Missing icon: $ICON_SOURCE" >&2
    exit 1
fi

if [[ ! -f "$SVG_ICON_SOURCE" ]]; then
    echo "Missing scalable icon: $SVG_ICON_SOURCE" >&2
    exit 1
fi

rm -rf "$PKG_ROOT"
mkdir -p "$CONTROL_DIR" "$INSTALL_DIR" "$DESKTOP_DIR" "$PNG_ICON_DIR" "$SVG_ICON_DIR" "$BIN_LINK_DIR" "$DOC_DIR"
chmod 0755 "$CONTROL_DIR" "$INSTALL_DIR" "$DESKTOP_DIR" "$PNG_ICON_DIR" "$SVG_ICON_DIR" "$BIN_LINK_DIR" "$DOC_DIR"
chmod g-s "$CONTROL_DIR" "$INSTALL_DIR" "$DESKTOP_DIR" "$PNG_ICON_DIR" "$SVG_ICON_DIR" "$BIN_LINK_DIR" "$DOC_DIR"
find "$PKG_ROOT/usr/share/icons" -type d -exec chmod 0755 {} +
find "$PKG_ROOT/usr/share/icons" -type d -exec chmod g-s {} +

cp "$BIN_SOURCE" "$INSTALL_DIR/$APP_NAME"
cp "$RESOURCES_SOURCE" "$INSTALL_DIR/resources.neu"
cp "$ICON_SOURCE" "$PNG_ICON_DIR/${PACKAGE_NAME}.png"
cp "$SVG_ICON_SOURCE" "$SVG_ICON_DIR/${PACKAGE_NAME}.svg"
cp "$README_SOURCE" "$DOC_DIR/README.md"
cp "$LICENSE_SOURCE" "$DOC_DIR/copyright"
chmod 755 "$INSTALL_DIR/$APP_NAME"
chmod 644 "$INSTALL_DIR/resources.neu"
chmod 644 "$PNG_ICON_DIR/${PACKAGE_NAME}.png" "$SVG_ICON_DIR/${PACKAGE_NAME}.svg"
chmod 644 "$DOC_DIR/README.md" "$DOC_DIR/copyright"

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
    BUILD_DATE="$(date -u -R -d "@$SOURCE_DATE_EPOCH")"
else
    BUILD_DATE="$(date -u -R)"
fi

cat > "$DOC_DIR/changelog.Debian" <<EOF
$PACKAGE_NAME ($VERSION) unstable; urgency=medium

  * Package CodeTimer release $VERSION.

 -- $MAINTAINER  $BUILD_DATE
EOF
gzip -n -9 "$DOC_DIR/changelog.Debian"
chmod 644 "$DOC_DIR/changelog.Debian.gz"

cat > "$CONTROL_DIR/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $PACKAGE_ARCH
Maintainer: $MAINTAINER
Depends: libgtk-3-0, libwebkit2gtk-4.1-0 | libwebkit2gtk-4.0-37
Description: CodeTimer desktop widget for Kimai
EOF
chmod 644 "$CONTROL_DIR/control"

cat > "$DESKTOP_DIR/${PACKAGE_NAME}.desktop" <<EOF
[Desktop Entry]
Name=$APP_NAME
Comment=Desktop timer widget for Kimai time tracking
Exec=/opt/$PACKAGE_NAME/$APP_NAME
Icon=$PACKAGE_NAME
Type=Application
Categories=Office;ProjectManagement;
Keywords=Kimai;timer;time tracking;timesheet;
StartupNotify=true
StartupWMClass=$APP_NAME
Terminal=false
EOF
chmod 644 "$DESKTOP_DIR/${PACKAGE_NAME}.desktop"

ln -sf "/opt/$PACKAGE_NAME/$APP_NAME" "$BIN_LINK_DIR/$PACKAGE_NAME"

find "$PKG_ROOT" -type d -exec chmod 0755 {} +
find "$PKG_ROOT" -type d -exec chmod g-s {} +

dpkg-deb --root-owner-group --build "$PKG_ROOT" "$OUTPUT_DEB"
echo "Created: $OUTPUT_DEB"

echo
echo "Package metadata:"
dpkg-deb --info "$OUTPUT_DEB"

echo
echo "Package contents:"
dpkg-deb --contents "$OUTPUT_DEB"

echo
echo "Validating desktop entry..."
if optional_command desktop-file-validate; then
    desktop-file-validate "$DESKTOP_DIR/${PACKAGE_NAME}.desktop"
else
    echo "Skipping desktop-file-validate: command not found"
fi

echo
echo "Running lintian..."
if optional_command lintian; then
    lintian "$OUTPUT_DEB"
else
    echo "Skipping lintian: command not found"
fi
