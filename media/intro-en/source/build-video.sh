#!/bin/zsh
set -euo pipefail
task_root="${0:A:h:h:h:h}"
cd "$task_root/mxlogger_analyzer/mxlogger_analyzer_lib"
flutter test --no-pub "$task_root/media/intro-en/source/capture_ui.dart" --reporter expanded
cd "$task_root"
python3 media/intro-en/source/prepare.py
xcrun swiftc -O -module-cache-path /private/tmp/mxlogger-video-swift-cache \
  media/intro-en/source/render.swift -o media/intro-en/working/render
media/intro-en/working/render "$task_root"
python3 media/intro-en/source/verify.py
