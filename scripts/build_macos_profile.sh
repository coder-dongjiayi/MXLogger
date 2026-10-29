#!/usr/bin/env bash
# Temporary-branch diagnostic only. Does not rebuild or package the regular Demo.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE="$ROOT/platform/macOS/MXLoggerProfile"
BUILD="$ROOT/build/macos-profile"
APP="$BUILD/MXLoggerProfile.app"
SDK=$(xcrun --sdk macosx --show-sdk-path)
MINIMUM=$(python3 - "$SDK" <<'PY'
import json,sys
from pathlib import Path
sdk=json.loads((Path(sys.argv[1])/'SDKSettings.json').read_text())
floor=sdk['SupportedTargets']['macosx']['MinimumDeploymentTarget']
print(max(['10.15',floor],key=lambda v:tuple(map(int,v.split('.')))))
PY
)
mkdir -p "$BUILD/logs" "$BUILD/modules/MXLogger" "$APP/Contents/MacOS" "$APP/Contents/Resources/Workers"
cat > "$BUILD/modules/MXLogger/module.modulemap" <<EOF
module MXLogger {
  header "$ROOT/platform/iOS/MXLogger/MXLogger/include/MXLogger/MXLogger.h"
  export *
}
EOF
for MODE in baseline sampled; do
    echo ">> Release worker: $MODE (arm64 + x86_64)"
    WORKER="$APP/Contents/Resources/Workers/$MODE"
    CORE_BUILD="$BUILD/core-$MODE"
    mkdir -p "$WORKER"
    DEFINE=MXLOGGER_MACOS_BASELINE
    SWIFT_DEFINE=MXLOGGER_BASELINE
    if [ "$MODE" = sampled ]; then DEFINE=MXLOGGER_MACOS_PROFILING; SWIFT_DEFINE=MXLOGGER_PROFILE; fi
    cmake -S "$ROOT/Core" -B "$CORE_BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        '-DCMAKE_OSX_ARCHITECTURES=arm64;x86_64' "-DCMAKE_OSX_DEPLOYMENT_TARGET=$MINIMUM" \
        "-DCMAKE_CXX_FLAGS=-D$DEFINE=1" '-DCMAKE_CXX_FLAGS_RELEASE=-Os -DNDEBUG' \
        '-DCMAKE_C_FLAGS_RELEASE=-Os -DNDEBUG' -DMXLOGGER_BUILD_TESTS=OFF -DMXLOGGER_INSTALL=OFF \
        > "$BUILD/logs/configure-$MODE.log" 2>&1 || { tail -n 80 "$BUILD/logs/configure-$MODE.log"; exit 1; }
    cmake --build "$CORE_BUILD" --target MXLoggerCore --parallel 4 \
        > "$BUILD/logs/core-$MODE.log" 2>&1 || { tail -n 80 "$BUILD/logs/core-$MODE.log"; exit 1; }
    xcrun clang++ -isysroot "$SDK" -arch arm64 -arch x86_64 "-mmacosx-version-min=$MINIMUM" \
        -std=c++17 -Os -DNDEBUG -fobjc-arc -fPIC -dynamiclib "-D$DEFINE=1" \
        -I"$ROOT/Core" -I"$ROOT/Core/include" \
        "$ROOT/platform/iOS/MXLogger/MXLogger/MXLogger.mm" "$SOURCE/ProfileBridge.mm" \
        "$CORE_BUILD/libMXLoggerCore.a" -framework Foundation \
        -install_name @rpath/libMXLoggerProfile.dylib -o "$WORKER/libMXLoggerProfile.dylib" \
        > "$BUILD/logs/bridge-$MODE.log" 2>&1 || { tail -n 80 "$BUILD/logs/bridge-$MODE.log"; exit 1; }
    for ARCH in arm64 x86_64; do
        xcrun swiftc -sdk "$SDK" -target "$ARCH-apple-macosx$MINIMUM" -swift-version 5 \
            -O -whole-module-optimization -parse-as-library -D "$SWIFT_DEFINE" \
            -module-cache-path "$BUILD/module-cache" -I "$BUILD/modules" \
            -import-objc-header "$SOURCE/ProfileBridge.h" \
            "$ROOT/platform/macOS/MXLoggerDemo/MXLoggerDemo/DemoSession.swift" "$SOURCE/WorkerMain.swift" \
            -L "$WORKER" -lMXLoggerProfile -Xlinker -rpath -Xlinker @executable_path \
            -o "$BUILD/worker-$MODE-$ARCH" > "$BUILD/logs/swift-$MODE-$ARCH.log" 2>&1 || {
            tail -n 80 "$BUILD/logs/swift-$MODE-$ARCH.log"; exit 1;
        }
    done
    xcrun lipo -create "$BUILD/worker-$MODE-arm64" "$BUILD/worker-$MODE-x86_64" -output "$WORKER/MXLoggerWorker"
    codesign --force --sign - "$WORKER/libMXLoggerProfile.dylib" "$WORKER/MXLoggerWorker"
done
echo '>> Diagnostic app'
for ARCH in arm64 x86_64; do
    xcrun swiftc -sdk "$SDK" -target "$ARCH-apple-macosx$MINIMUM" -swift-version 5 \
        -O -whole-module-optimization -parse-as-library -module-cache-path "$BUILD/module-cache" \
        "$SOURCE/ProfileApp.swift" -o "$BUILD/app-$ARCH" > "$BUILD/logs/app-$ARCH.log" 2>&1 || {
        tail -n 80 "$BUILD/logs/app-$ARCH.log"; exit 1;
    }
done
xcrun lipo -create "$BUILD/app-arm64" "$BUILD/app-x86_64" -output "$APP/Contents/MacOS/MXLoggerProfile"
python3 - "$APP" "$MINIMUM" "$ROOT" <<'PY'
import hashlib,json,plistlib,subprocess,sys
from pathlib import Path
app,minimum,root=Path(sys.argv[1]),sys.argv[2],Path(sys.argv[3])
with (app/'Contents/Info.plist').open('wb') as f:
    plistlib.dump(dict(CFBundleIdentifier='com.mxlogger.macos.profile', CFBundleName='MXLoggerProfile',
        CFBundleExecutable='MXLoggerProfile',CFBundlePackageType='APPL',CFBundleShortVersionString='1.0',
        CFBundleVersion='1',LSMinimumSystemVersion=minimum,NSHighResolutionCapable=True),f)
files=sorted(p for base in [root/'Core',root/'platform/macOS/MXLoggerProfile'] for p in base.rglob('*')
             if p.is_file() and 'build' not in p.relative_to(base).parts
             and p.suffix in ['.cpp','.hpp','.h','.c','.S','.swift','.mm'])
files += [root/'platform/macOS/MXLoggerDemo/MXLoggerDemo/DemoSession.swift',root/'platform/iOS/MXLogger/MXLogger/MXLogger.mm']
h=hashlib.sha256()
for p in files:
    h.update(str(p.relative_to(root)).encode()); h.update(p.read_bytes())
info=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
    branch=subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip(),
    source_sha256=h.hexdigest(),minimum_macos=minimum,cpp_flags='-Os -DNDEBUG -std=c++17',
    swift_flags='-O -whole-module-optimization -swift-version 5',
    xcode=subprocess.check_output(['xcodebuild','-version'],text=True).strip())
(app/'Contents/Resources/build-info.json').write_text(json.dumps(info,indent=2))
PY
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/MXLoggerProfile" --self-test --report-dir "$BUILD/self-test" \
    > "$BUILD/logs/self-test.log" 2>&1 || { tail -n 100 "$BUILD/logs/self-test.log"; exit 1; }
STAGE=$(mktemp -d "$BUILD/dmg-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/MXLoggerProfile.app"
cp "$SOURCE/README.md" "$STAGE/README.md"
cp "$ROOT/LICENSE.TXT" "$STAGE/LICENSE.TXT"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname MXLoggerProfile -srcfolder "$STAGE" -format UDZO -ov "$BUILD/MXLoggerProfile-macOS.dmg"
hdiutil verify "$BUILD/MXLoggerProfile-macOS.dmg"
echo ">> PASS: $BUILD/MXLoggerProfile-macOS.dmg"
