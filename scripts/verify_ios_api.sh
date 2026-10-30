#!/usr/bin/env bash
# Run the shared Apple contract and iOS-only lifecycle tests on an installed runtime.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT/build/ios-api-tests"
BUILD=$(mktemp -d "$ROOT/build/ios-api-tests/run-XXXXXX")
xcrun simctl list runtimes --json > "$BUILD/runtimes.json"
python3 - "$BUILD/runtimes.json" > "$BUILD/selection.txt" <<'PY'
import json
import platform
import sys

runtimes = json.load(open(sys.argv[1]))['runtimes']
for runtime in sorted(runtimes, key=lambda r: tuple(map(int, r['version'].split('.'))), reverse=True):
    if not runtime.get('isAvailable') or runtime.get('platform') != 'iOS':
        continue
    architectures = runtime.get('supportedArchitectures', [])
    if architectures and platform.machine() not in architectures:
        continue
    devices = [d for d in runtime.get('supportedDeviceTypes', []) if d.get('productFamily') == 'iPhone']
    if devices:
        print(runtime['identifier'], devices[0]['identifier'])
        break
else:
    raise SystemExit('No compatible installed iOS simulator runtime. Install one in Xcode Settings > Components.')
PY
read -r RUNTIME DEVICE_TYPE < "$BUILD/selection.txt"
DEVICE=$(xcrun simctl create MXLogger-API-Tests "$DEVICE_TYPE" "$RUNTIME")
printf '%s\n' "$DEVICE" > "$BUILD/device-id.txt"
cleanup() {
    xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
    xcrun simctl delete "$DEVICE" >/dev/null 2>&1 || true
}
trap cleanup EXIT
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b > "$BUILD/boot.log" 2>&1
xcodebuild -quiet -project "$ROOT/platform/iOS/MXLogger/MXLogger.xcodeproj" \
    -scheme MXLogger -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEVICE" -parallel-testing-enabled NO \
    -enableCodeCoverage YES -derivedDataPath "$BUILD/DerivedData" \
    -resultBundlePath "$BUILD/Tests.xcresult" CODE_SIGNING_ALLOWED=NO test \
    > "$BUILD/tests.log" 2>&1 || { tail -n 80 "$BUILD/tests.log"; exit 1; }
xcrun xcresulttool get test-results summary --path "$BUILD/Tests.xcresult" --format json \
    > "$BUILD/summary.json"
python3 - "$BUILD/summary.json" <<'PY'
import json
import sys
report = json.load(open(sys.argv[1]))
if report.get('failedTests') or not report.get('passedTests') or report.get('skippedTests'):
    raise SystemExit('Expected passing iOS API tests with no skips: ' + str(report))
print(f">> iOS simulator: {report['passedTests']} tests passed")
PY
echo ">> iOS test results: $BUILD"
