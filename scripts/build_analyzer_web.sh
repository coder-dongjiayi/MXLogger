#!/usr/bin/env bash
# 用法（仓库根目录）：bash scripts/build_web.sh [--base-href /mxlogger/]
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/../mxlogger_analyzer"

bash "$script_dir/prepare_web.sh"
flutter build web --release --no-pub --csp --no-web-resources-cdn \
  --pwa-strategy=none -t lib/main_web.dart "$@"
