#!/bin/zsh
# Baut Lex.app ohne Xcode-Projekt.
#   ./build.sh            → build/Lex.app
#   ./build.sh install    → zusätzlich nach /Applications kopieren und starten
#   ./build.sh uninstall  → Login-Start entfernen, App beenden und löschen
set -euo pipefail
cd "${0:A:h}"

APP_ID="de.ralfw.lex"
AGENT="$HOME/Library/LaunchAgents/$APP_ID.plist"
INSTALLED="/Applications/Lex.app"

if [[ "${1:-}" == "uninstall" ]]; then
  rm -f "$AGENT"
  pkill -x Lex 2>/dev/null || true
  rm -rf "$INSTALLED"
  echo "Lex deinstalliert (Historie und ~/.config/lex bleiben erhalten)."
  exit 0
fi

swift build -c release --product Lex
BIN="$(swift build -c release --show-bin-path)/Lex"

APP="build/Lex.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Lex"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$APP_ID</string>
  <key>CFBundleName</key><string>Lex</string>
  <key>CFBundleDisplayName</key><string>Lex</string>
  <key>CFBundleExecutable</key><string>Lex</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>$(date +%Y%m%d%H%M)</string>
  <key>CFBundleDevelopmentRegion</key><string>de</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Gebaut: $APP"

if [[ "${1:-}" == "install" ]]; then
  pkill -x Lex 2>/dev/null || true
  rm -rf "$INSTALLED"
  cp -R "$APP" "$INSTALLED"
  # Ein vorhandener Login-Start wird auf die installierte Kopie umgebogen.
  if [[ -f "$AGENT" ]]; then
    /usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 $INSTALLED/Contents/MacOS/Lex" "$AGENT"
  fi
  open "$INSTALLED"
  echo "Installiert: $INSTALLED – Login-Start in den Einstellungen (/settings)."
fi
