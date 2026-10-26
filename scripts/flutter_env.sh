#!/usr/bin/env bash
# 由发布脚本 source；参数是宿主 Flutter 工程目录。
mxlogger_resolve_flutter() {
  local project_dir sdk_dir resolved
  project_dir=$(cd "$1" && pwd)

  if [ -n "${FLUTTER_BIN:-}" ]; then
    if ! resolved=$(command -v "$FLUTTER_BIN"); then
      printf 'FLUTTER_BIN 不可执行：%s\n' "$FLUTTER_BIN" >&2
      return 1
    fi
    FLUTTER_BIN="$resolved"
    return 0
  fi

  if resolved=$(command -v flutter); then
    FLUTTER_BIN="$resolved"
    return 0
  fi

  # FVM 的工程 SDK 链接可能位于宿主工程或仓库的上级目录。
  sdk_dir="$project_dir"
  while [ "$sdk_dir" != / ]; do
    if [ -x "$sdk_dir/.fvm/flutter_sdk/bin/flutter" ]; then
      FLUTTER_BIN="$sdk_dir/.fvm/flutter_sdk/bin/flutter"
      return 0
    fi
    sdk_dir=$(dirname "$sdk_dir")
  done

  # IDE 生成的配置记录了 SDK 的实际位置，不依赖交互式 shell 的 PATH。
  if [ -f "$project_dir/android/local.properties" ]; then
    sdk_dir=$(sed -n 's/^flutter\.sdk=//p' "$project_dir/android/local.properties")
    sdk_dir=${sdk_dir%$'\r'}
    if [ -n "$sdk_dir" ] && [ -x "$sdk_dir/bin/flutter" ]; then
      FLUTTER_BIN="$sdk_dir/bin/flutter"
      return 0
    fi
  fi

  for sdk_dir in "${FLUTTER_ROOT:-}" "$HOME/fvm/default"; do
    if [ -n "$sdk_dir" ] && [ -x "$sdk_dir/bin/flutter" ]; then
      FLUTTER_BIN="$sdk_dir/bin/flutter"
      return 0
    fi
  done

  echo '未找到 Flutter。请将 SDK 加入 PATH，或设置 FLUTTER_BIN=/path/to/flutter/bin/flutter。' >&2
  return 1
}
