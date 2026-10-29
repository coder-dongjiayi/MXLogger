#!/usr/bin/env bash
# Package the native Demo from this checkout, after CI verification has passed.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build/macos-native-demo"
mkdir -p "$BUILD"
pod install --project-directory="$ROOT/platform/macOS/MXLoggerDemo" > "$BUILD/dmg-pods.log" 2>&1 || {
    cat "$BUILD/dmg-pods.log"; exit 1;
}
xcodebuild -quiet -workspace "$ROOT/platform/macOS/MXLoggerDemo/MXLoggerDemo.xcworkspace" \
    -scheme MXLoggerDemo -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$BUILD" 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY=- build > "$BUILD/dmg-build.log" 2>&1 || {
    tail -n 100 "$BUILD/dmg-build.log"; exit 1;
}
APP="$BUILD/Build/Products/Release/MXLoggerDemo.app"
for ARCH in arm64 x86_64; do
    xcrun lipo "$APP/Contents/MacOS/MXLoggerDemo" -verify_arch "$ARCH"
done
"$APP/Contents/MacOS/MXLoggerDemo" --smoke-test > "$BUILD/dmg-smoke.log" 2>&1 || {
    cat "$BUILD/dmg-smoke.log"; exit 1;
}
grep 'MXLOGGER_NATIVE_MACOS_DEMO_OK' "$BUILD/dmg-smoke.log"

STAGE=$(mktemp -d "$BUILD/dmg-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/MXLoggerDemo.app"
codesign --verify --deep --strict "$STAGE/MXLoggerDemo.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/LICENSE.TXT" "$STAGE/LICENSE.TXT"
cat > "$STAGE/README.txt" <<'EOF'
MXLogger native macOS Demo (Release, Apple Silicon + Intel)

Drag MXLoggerDemo.app to Applications to install.
This CI demo uses an ad-hoc signature and is not notarized by Apple.
EOF
OUTPUT="$BUILD/MXLoggerDemo-macOS-Release.dmg"
hdiutil create -volname MXLoggerDemo -srcfolder "$STAGE" -format UDZO -ov "$OUTPUT"
hdiutil verify "$OUTPUT"
echo ">> Release DMG: $OUTPUT"
