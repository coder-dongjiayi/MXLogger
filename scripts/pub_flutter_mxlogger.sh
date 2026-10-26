#!/usr/bin/env bash
# 发布 flutter_mxlogger 到 pub.dev。
#
# 用法：
#   scripts/pub_flutter_mxlogger.sh --dry-run   # 只校验，不上传
#   scripts/pub_flutter_mxlogger.sh             # 上传
set -euo pipefail

cd "$(dirname "$0")/../flutter_mxlogger"

# 发布固定使用 pub.dev，避免本机 PUB_HOSTED_URL 指向只读镜像。
export PUB_HOSTED_URL=https://pub.dev

flutter pub publish "$@"
