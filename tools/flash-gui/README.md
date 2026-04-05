# flash-gui（macOS）

基于 SwiftUI 与 SwiftPM 开发的 macOS 原生 ESP32 烧录与串口监视工具。

## 功能特性

- 一键烧录 `.bin` 或 `.zip` 固件到 ESP32-S3（地址 `0x0`）
- 选择 `.zip` 时自动解压并查找 `.bin` 固件（优先 `merged-binary.bin`）
- 一键擦除 Flash
- 串口监视器支持：
  - 串口与波特率选择
  - 启动/停止
  - 发送单行命令（自动追加 `\n`）
  - 清空日志
  - 保存日志到文件
- 启动时环境预检：
  - 系统 `python3`
  - 应用内置 `esptool` 可用性

`esptool` 及其 Python 依赖已内置在仓库：

- `tools/flash-gui/vendor/python`

如果环境检查失败，一般只需要安装 Python 3（不需要再 `pip install esptool`）。

## 构建与运行（仅命令行）

```bash
cd tools/flash-gui
swift build
swift run
```

发布构建：

```bash
swift build -c release
```

构建完成后，产物在以下位置：

- 可执行文件（实际路径）：`.build/arm64-apple-macosx/release/flash-gui`
- 可执行文件（快捷链接）：`.build/release/flash-gui`

可直接运行：

```bash
./.build/release/flash-gui
```

## 打包 DMG（命令行）

先执行 release 构建：

```bash
cd tools/flash-gui
swift build -c release
```

然后执行以下命令生成 `.app` 和 `.dmg`：

```bash
APP_NAME="FlashGUI"
VERSION="2.2.5"
DIST_DIR="$PWD/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
STAGE_DIR="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-macOS-arm64.dmg"

rm -rf "$APP_DIR" "$STAGE_DIR" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp .build/release/flash-gui "$APP_DIR/Contents/MacOS/flash-gui"
chmod +x "$APP_DIR/Contents/MacOS/flash-gui"
cp -R vendor "$APP_DIR/Contents/Resources/vendor"

cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FlashGUI</string>
    <key>CFBundleDisplayName</key>
    <string>FlashGUI</string>
    <key>CFBundleIdentifier</key>
    <string>com.xiaozhi.flashgui</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>2.2.5</string>
    <key>CFBundleExecutable</key>
    <string>flash-gui</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"
```

打包完成后文件位置：

- `.app`：`tools/flash-gui/dist/FlashGUI.app`
- `.dmg`：`tools/flash-gui/dist/FlashGUI-2.2.5-macOS-arm64.dmg`

## 实际使用的烧录命令

烧录：

```bash
PYTHONPATH=<内置vendor/python> python3 -m esptool --chip esp32s3 --port <PORT> --baud <BAUD> write_flash -z 0x0 <BIN_PATH>
```

擦除：

```bash
PYTHONPATH=<内置vendor/python> python3 -m esptool --chip esp32s3 --port <PORT> erase_flash
```

## 说明

- 串口监视器运行时，GUI 会禁止发起烧录。
- GUI 不会自动安装 Python 3，本工具仅内置 `esptool` 相关依赖。
- `.zip` 固件包仅支持自动提取其中的 `.bin` 固件并按 `0x0` 烧录。
- 若 ZIP 内有多个 `.bin`，会优先使用 `merged-binary.bin`，否则按文件名排序取第一个。
- 若高速烧录失败，请降低波特率到 `460800` 或 `115200` 重试。
- 默认仅显示可烧录串口（隐藏蓝牙串口），可在界面中关闭该过滤。
- 烧录日志支持自动滚动到最新内容。
