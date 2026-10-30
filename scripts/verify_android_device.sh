#!/usr/bin/env bash
# Stage 2: actual Android instrumentation, after the global Core-test gate.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build/android-device-tests"
mkdir -p "$BUILD"
bash "$ROOT/platform/Android/MXLogger/gradlew" -p "$ROOT/platform/Android/MXLogger" \
    --no-daemon --console=plain :mxlogger:connectedDefaultCppDebugAndroidTest \
    > "$BUILD/tests.log" 2>&1 || { tail -n 100 "$BUILD/tests.log"; exit 1; }
python3 - "$ROOT/platform/Android/MXLogger/mxlogger/build/outputs/androidTest-results/connected" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
tests = failures = skipped = 0
for path in Path(sys.argv[1]).rglob('TEST-*.xml'):
    report = ET.parse(path).getroot()
    tests += int(report.get('tests', 0))
    failures += int(report.get('failures', 0)) + int(report.get('errors', 0))
    skipped += int(report.get('skipped', 0))
if not tests or failures or skipped:
    raise SystemExit(f'Android instrumentation: tests={tests}, failures={failures}, skipped={skipped}')
print(f'PASS: {tests} Android device tests')
PY
