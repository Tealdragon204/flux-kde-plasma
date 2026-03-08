#!/usr/bin/env bash
# install.sh — Install Night Color Override plasmoid for KDE Plasma 6
set -euo pipefail

PLASMOID_ID="com.local.nightcoloroverride"
SRC_DIR="$(cd "$(dirname "$0")/$PLASMOID_ID" && pwd)"
DEST_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"

echo "==> Night Color Override — installer"
echo

# Dependency check
if ! python3 -c "import dbus" 2>/dev/null; then
    echo "WARNING: python-dbus is not installed."
    echo "         Run:  sudo pacman -S python-dbus"
    echo "         The daemon will not start without it."
    echo
fi

# Copy files
echo "Installing to: $DEST_DIR"
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
cp -r "$SRC_DIR"/. "$DEST_DIR/"
chmod +x "$DEST_DIR/contents/scripts/nightcolor-mode.py"

# Register with Plasma (ignore errors from plasmapkg6 if widget is already added)
if command -v plasmapkg6 &>/dev/null; then
    plasmapkg6 --install "$DEST_DIR" 2>/dev/null \
        || plasmapkg6 --upgrade "$DEST_DIR" 2>/dev/null \
        || true
fi

echo
echo "Done! To add the widget:"
echo "  Right-click the system tray → Add Widgets → search 'Night Color Override'"
echo
echo "To uninstall:"
echo "  rm -rf \"$DEST_DIR\""
echo "  plasmapkg6 --remove $PLASMOID_ID"
