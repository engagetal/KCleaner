#!/usr/bin/env bash
# Builds KCleaner.app with the Xcode Command Line Tools. No Xcode project needed.
#
#   bash build.sh             builds build/KCleaner.app
#   bash build.sh --install   also copies it to /Applications and opens it
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="KCleaner"
APP="build/$APP_NAME.app"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "The Swift compiler isn't installed. Install the Command Line Tools, then run this again:"
  echo "    xcode-select --install"
  exit 1
fi

# 1. Privacy check -----------------------------------------------------------
# KCleaner must never connect to anything. Refuse to build if the source contains
# anything that could open a network connection or load something from the web.
echo "Checking the source for network code..."
FORBIDDEN='URLSession|URLRequest|NSURLConnection|NWConnection|NWListener|NWPathMonitor|NWBrowser|import Network|import WebKit|WKWebView|CFSocket|CFStream|CFHost|getaddrinfo|gethostbyname|socket\(|https?://|contentsOf: *URL|Sparkle|Firebase|Sentry|Crashlytics|Mixpanel|Amplitude|Segment'
if grep -nE "$FORBIDDEN" Sources/*.swift; then
  echo ""
  echo "Build stopped: the lines above look like network or tracking code."
  echo "KCleaner must never connect to the internet."
  exit 1
fi
echo "  None found."

# 2. Compile ------------------------------------------------------------------
echo "Compiling $APP_NAME..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc \
  -O \
  -swift-version 5 \
  -target "$(uname -m)-apple-macos13.0" \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/$APP_NAME"

cp Info.plist "$APP/Contents/Info.plist"
# Remember where this folder is, so Uninstall can offer to remove it too. Stays on this Mac.
plutil -insert KCSourceFolder -string "$PWD" "$APP/Contents/Info.plist"
cp PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
if [[ -f Branding/engagetal-logo.png ]]; then
  cp Branding/engagetal-logo.png "$APP/Contents/Resources/engagetal-logo.png"
  echo "  Using Branding/engagetal-logo.png"
fi

# 3. Finder icon (the app draws its own icon; this just saves it as an .icns) --
make_icon() {
  local work="build/icon"
  rm -rf "$work"
  mkdir -p "$work/AppIcon.iconset"
  "$APP/Contents/MacOS/$APP_NAME" --render-icon "$work/icon-1024.png"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$work/icon-1024.png" --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    local double=$((size * 2))
    sips -z "$double" "$double" "$work/icon-1024.png" --out "$work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$work/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
}
echo "Making the app icon..."
make_icon || echo "  Couldn't make the Finder icon. The app still works and shows its icon in the Dock."

# 4. Sign ---------------------------------------------------------------------
echo "Signing (ad-hoc, on this Mac only)..."
codesign --force --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
  echo "Installing to /Applications..."
  if pgrep -xq "$APP_NAME"; then
    echo "  Quit $APP_NAME first, then run this again."
    exit 1
  fi
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" /Applications/
  open "/Applications/$APP_NAME.app"
  echo "Done. $APP_NAME is in /Applications."
else
  echo "Built $APP"
  echo "Open it with:  open $APP"
fi
