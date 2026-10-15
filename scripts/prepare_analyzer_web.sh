#!/usr/bin/env bash
# 用法（仓库根目录）：bash scripts/prepare_web.sh
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/../mxlogger_analyzer"

flutter pub get --offline

# Share browser runtime resources with the extension, excluding its manifest,
# background script and Chromium-only bootstrap. These copies are generated.
python3 - <<'PY'
from pathlib import Path
import shutil

source = Path('chrome_extension/web')
destination = Path('web')
for name in ['bridge.js', 'font_bridge.js', 'font-manifest.json',
             'sqlite3.wasm', 'shell.css', 'favicon.png']:
    shutil.copy2(source / name, destination / name)
shutil.copytree(source / 'samples', destination / 'samples', dirs_exist_ok=True)
PY

# Parse/decrypt/query in a separate Worker, so large imports leave the UI responsive.
dart compile js -O2 --csp chrome_extension/lib/worker.dart -o web/worker.js
