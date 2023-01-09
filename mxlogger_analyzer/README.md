# mxlogger_analyzer
https://github.com/coder-dongjiayi/MXLogger.git

##  打包


flutter build macos -t lib/main_desktop.dart

### 应用图标生成

sips -z 16 16     logo.png --out icons.iconset/icon_16x16.png
sips -z 32 32     logo.png --out icons.iconset/icon_16x16@2x.png
sips -z 32 32     logo.png --out icons.iconset/icon_32x32.png
sips -z 64 64     logo.png --out icons.iconset/icon_32x32@2x.png
sips -z 128 128   logo.png --out icons.iconset/icon_128x128.png
sips -z 256 256   logo.png --out icons.iconset/icon_128x128@2x.png
sips -z 256 256   logo.png --out icons.iconset/icon_256x256.png
sips -z 512 512   logo.png --out icons.iconset/icon_256x256@2x.png
sips -z 512 512   logo.png --out icons.iconset/icon_512x512.png
sips -z 1024 1024   logo.png --out icons.iconset/icon_512x512@2x.png

iconutil -c icns icons.iconset -o icon.icns

### dmg包生成
appdmg <config-json-path> <output-dmg-path-with-file-name>
#### 如果安装了nvm管理 node版本，需要增加npx
npx appdmg ./installers/dmg_creator/config.json ./installers/dmg_creator/mxlogger_analyzer.app

