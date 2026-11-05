#!/bin/sh
# 生成用于 OHPM 分发的 Release HAR，仅本地构建和校验，不执行发布。
# 用法：sh scripts/ohos_release.sh 2.3.0
# 可选：DEVECO_HOME=/path/to/DevEco-Studio.app/Contents
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' '错误：请先安装 Python 3。' >&2
  exit 1
fi
exec python3 "$SCRIPT_DIR/build_ohos_har.py" "$@"
