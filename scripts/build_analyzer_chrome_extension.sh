#!/usr/bin/env bash
# 用法（仓库根目录）：bash scripts/build_analyzer_chrome_extension.sh <版本号>
set -euo pipefail

usage() {
  printf '用法：bash scripts/build_analyzer_chrome_extension.sh <版本号>\n'
  printf '示例：bash scripts/build_analyzer_chrome_extension.sh 1.0.0\n'
}

if [[ $# -eq 1 && ( "$1" == "--help" || "$1" == "-h" ) ]]; then
  usage
  exit 0
fi
if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

extension_version="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/../mxlogger_analyzer/chrome_extension"
# Validate before invoking Flutter; packaging uses the same required argument.
python3 tool/package.py --version "$extension_version" --validate-only
flutter pub get --offline
flutter build web --release --csp --no-web-resources-cdn --pwa-strategy=none --base-href /
dart compile js -O2 --csp lib/worker.dart -o build/web/worker.js
mkdir -p dist
python3 tool/package.py --version "$extension_version"
