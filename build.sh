#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_ROOT="$(mktemp -d /tmp/mediaprimekey-build.XXXXXX)"
trap 'rm -rf "$STAGING_ROOT"' EXIT

APP_DIR="$STAGING_ROOT/MediaPrimeKey.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
STAGED_ARCHIVE_PATH="$STAGING_ROOT/MediaPrimeKey.zip"
DIST_APP_DIR="$DIST_DIR/MediaPrimeKey.app"
ARCHIVE_PATH="$DIST_DIR/MediaPrimeKey.zip"
BUILD_DIR="$PROJECT_DIR/.build"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
TMP_DIR="$BUILD_DIR/tmp"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
DEVELOPER_DIR="$(xcode-select -p)"

if [[ -d "$DEVELOPER_DIR/SDKs/MacOSX15.4.sdk" ]]; then
  SDK_PATH="$DEVELOPER_DIR/SDKs/MacOSX15.4.sdk"
else
  SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
fi

mkdir -p "$DIST_DIR" "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR" "$TMP_DIR" "$ICONSET_DIR"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

sips -s format png -z 16 16 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
python3 "$PROJECT_DIR/Scripts/make_icns.py" "$ICONSET_DIR" "$RESOURCES_DIR/AppIcon.icns"

for build_arch in arm64 x86_64; do
  ARCH_MODULE_CACHE="$MODULE_CACHE_DIR/$build_arch"
  mkdir -p "$ARCH_MODULE_CACHE"

  CLANG_MODULE_CACHE_PATH="$ARCH_MODULE_CACHE" \
  TMPDIR="$TMP_DIR" \
  swiftc \
    -O \
    -sdk "$SDK_PATH" \
    -module-cache-path "$ARCH_MODULE_CACHE" \
    -swift-version 5 \
    -target "$build_arch-apple-macos13.0" \
    -framework AppKit \
    -framework ApplicationServices \
    -framework ServiceManagement \
    "$PROJECT_DIR"/Sources/MediaPrimeKey/*.swift \
    -o "$BUILD_DIR/MediaPrimeKey-$build_arch"
done

lipo -create \
  "$BUILD_DIR/MediaPrimeKey-arm64" \
  "$BUILD_DIR/MediaPrimeKey-x86_64" \
  -output "$MACOS_DIR/MediaPrimeKey"

# Sign in a local temporary directory. Cloud-backed workspace folders can attach
# Finder metadata immediately, which makes codesign reject an otherwise valid app.
xattr -cr "$APP_DIR"
codesign --force --deep --sign - \
  --identifier nl.mediaprimekey.app \
  "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

ditto -c -k --norsrc --keepParent "$APP_DIR" "$STAGED_ARCHIVE_PATH"

rm -rf "$DIST_APP_DIR"
rm -f "$ARCHIVE_PATH"
ditto --norsrc "$APP_DIR" "$DIST_APP_DIR"
cp "$STAGED_ARCHIVE_PATH" "$ARCHIVE_PATH"

echo "Built: $DIST_APP_DIR"
echo "Archive: $ARCHIVE_PATH"
