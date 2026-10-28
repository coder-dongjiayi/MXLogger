#!/usr/bin/env bash
# 发布 flutter_mxlogger 到 pub.dev。
#
# 用法：
#   scripts/pub_flutter_mxlogger.sh --dry-run   # 只校验，不上传
#   scripts/pub_flutter_mxlogger.sh             # 上传
set -euo pipefail

MXLOGGER_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$MXLOGGER_SCRIPT_DIR/flutter_env.sh"
mxlogger_resolve_flutter "$MXLOGGER_SCRIPT_DIR/../platform/flutter_mxlogger/example"
printf '使用 Flutter: %s\n' "$FLUTTER_BIN"

cd "$MXLOGGER_SCRIPT_DIR/../platform/flutter_mxlogger"

# 发布固定使用 pub.dev，避免本机 PUB_HOSTED_URL 指向只读镜像。
export PUB_HOSTED_URL=https://pub.dev

"$FLUTTER_BIN" pub publish "$@"
