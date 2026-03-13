#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$ROOT_DIR/neutralino.config.json"
DIST_DIR="$ROOT_DIR/dist/CodeTimer"
PACKAGE_NAME="codetimer"
ARCH_INPUT="${1:-x64}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
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

APP_NAME="$(json_value "binaryName")"
VERSION="$(json_value "version")"
PACKAGE_ARCH="$(map_architecture "$ARCH_INPUT")"
BIN_NAME="$APP_NAME-linux_$ARCH_INPUT"
BIN_SOURCE="$DIST_DIR/$BIN_NAME"
RESOURCES_SOURCE="$DIST_DIR/resources.neu"
ICON_SOURCE="$ROOT_DIR/resources/icons/appicon.png"
PKG_ROOT="$ROOT_DIR/dist/deb/${PACKAGE_NAME}_${VERSION}_${PACKAGE_ARCH}"
INSTALL_DIR="$PKG_ROOT/opt/$PACKAGE_NAME"
CONTROL_DIR="$PKG_ROOT/DEBIAN"
DESKTOP_DIR="$PKG_ROOT/usr/share/applications"
ICON_DIR="$PKG_ROOT/usr/share/icons/hicolor/256x256/apps"
BIN_LINK_DIR="$PKG_ROOT/usr/bin"
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

rm -rf "$PKG_ROOT"
mkdir -p "$CONTROL_DIR" "$INSTALL_DIR" "$DESKTOP_DIR" "$ICON_DIR" "$BIN_LINK_DIR"
chmod 0755 "$CONTROL_DIR" "$INSTALL_DIR" "$DESKTOP_DIR" "$ICON_DIR" "$BIN_LINK_DIR"
chmod g-s "$CONTROL_DIR" "$INSTALL_DIR" "$DESKTOP_DIR" "$ICON_DIR" "$BIN_LINK_DIR"

cp "$BIN_SOURCE" "$INSTALL_DIR/$APP_NAME"
cp "$RESOURCES_SOURCE" "$INSTALL_DIR/resources.neu"
cp "$ICON_SOURCE" "$ICON_DIR/${PACKAGE_NAME}.png"
chmod 755 "$INSTALL_DIR/$APP_NAME"

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
Exec=/opt/$PACKAGE_NAME/$APP_NAME
Icon=$PACKAGE_NAME
Type=Application
Categories=Office;Utility;
Terminal=false
EOF
chmod 644 "$DESKTOP_DIR/${PACKAGE_NAME}.desktop"

ln -sf "/opt/$PACKAGE_NAME/$APP_NAME" "$BIN_LINK_DIR/$PACKAGE_NAME"

dpkg-deb --build "$PKG_ROOT" "$OUTPUT_DEB"
echo "Created: $OUTPUT_DEB"
