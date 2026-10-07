#!/bin/zsh
# Build Earshot and install it as a login LaunchAgent.
set -e
cd "${0:A:h}"

LABEL=arrow7000.earshot
APP="$HOME/Library/Application Support/Earshot/Earshot.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/Earshot.log"
BUILD=build/Earshot.app

autoload is-at-least
if ! is-at-least 14.2 "$(sw_vers -productVersion)"; then
  echo "Earshot needs macOS 14.2 or later." >&2; exit 1
fi
if ! command -v swiftc >/dev/null; then
  echo "swiftc not found. Install the Xcode Command Line Tools: xcode-select --install" >&2; exit 1
fi

echo "Building..."
rm -rf build && mkdir -p "$BUILD/Contents/MacOS"
cp Resources/Info.plist "$BUILD/Contents/"
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos14.2" Sources/main.swift -o "build/earshot-$arch"
done
lipo -create build/earshot-arm64 build/earshot-x86_64 -output "$BUILD/Contents/MacOS/earshot"
codesign -s - -f "$BUILD" 2>/dev/null

echo "Installing..."
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
mkdir -p "${APP:h}" "${AGENT:h}" && rm -rf "$APP" && cp -R "$BUILD" "$APP"
sed -e "s|__APP__|$APP|g" -e "s|__LOG__|$LOG|g" Resources/$LABEL.plist > "$AGENT"
launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo
echo "Earshot is running. If macOS asks to let Earshot record system audio, click Allow."
echo "Then in Screenshot (⌘⇧5) choose Options → Microphone → System Audio."
