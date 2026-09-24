#!/usr/bin/env bash
# 发布 mxlogger_analyzer_lib 到 pub.dev。
# mxlogger_analyzer 目录下的壳工程是 publish_to: none，不发布，只有内核包上传。
#
# 用法：
#   scripts/pub_mxlogger_analyzer.sh --dry-run   # 只校验，不上传
#   scripts/pub_mxlogger_analyzer.sh             # 上传（首次会打开浏览器做 Google 账号授权）
set -euo pipefail

cd "$(dirname "$0")/../mxlogger_analyzer/mxlogger_analyzer_lib"

# ~/.zshrc 里 PUB_HOSTED_URL 指向国内镜像 pub.flutter-io.cn，镜像是只读的、不能发布；
# 而 dart pub publish 已经没有 --server 选项（旧脚本那个参数不起作用），
# 上传地址只由 PUB_HOSTED_URL 决定，所以这里临时改回 pub.dev。
export PUB_HOSTED_URL=https://pub.dev

flutter pub publish "$@"
