#!/bin/sh
set -e

REPO="thunderfm/ProToolsReport"
INSTALL_DIR="$HOME/Applications"
APP_NAME="ProToolsReport.app"

echo "Installing Pro Tools Report..."

# Create ~/Applications if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Download and extract
curl -fsSL "https://github.com/$REPO/archive/refs/heads/master.tar.gz" \
  | tar -xz --strip-components=1 -C "$INSTALL_DIR" "ProToolsReport-master/$APP_NAME"

# Ensure binary is executable
chmod +x "$INSTALL_DIR/$APP_NAME/Contents/MacOS/ProToolsReport"

# Remove macOS quarantine flag so it opens without Gatekeeper blocking it
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true

echo ""
echo "Installed to $INSTALL_DIR/$APP_NAME"
echo ""
echo "After a Pro Tools crash, open Finder → go to ~/Applications → double-click ProToolsReport."
echo ""
echo "Tip: For full log access, grant Full Disk Access in:"
echo "  System Settings → Privacy & Security → Full Disk Access → add ProToolsReport.app"
