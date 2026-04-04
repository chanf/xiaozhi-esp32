# ESP32-S3 N16R8 固件编译构建指南（实操版）

本文基于本仓库一次真实构建过程整理，目标是编译出 `ESP32-S3 N16R8` 可用固件。

## 1. 先说明一个关键点

`ESP32-S3 N16R8` 只描述芯片资源规格（16MB Flash + 8MB PSRAM），**不等于具体开发板型号**。  
真正编译时仍要选择板型（决定引脚、外设、屏幕、音频方案）。

本次使用的板型是：

- `bread-compact-wifi`
- 变体：`bread-compact-wifi`（OLED 128x32）

## 2. 需要安装的软件与依赖

## 2.1 系统工具

- `git`
- `python3`
- `cmake`
- `ninja`
- （可选）`unzip`、`shasum`（用于产物检查）

macOS 可用：

```bash
xcode-select --install
brew install cmake ninja
```

## 2.2 ESP-IDF（必须）

本项目实际构建建议使用 `ESP-IDF >= 5.5.2`。  
即使 VSCode 装了 ESP-IDF 插件，如果终端里没有 `idf.py`，也需要单独安装 CLI 环境。

本次安装命令：

```bash
git clone --depth 1 --branch v5.5.2 https://github.com/espressif/esp-idf.git /tmp/esp-idf-v5.5.2
/tmp/esp-idf-v5.5.2/install.sh esp32s3
```

安装后会生成：

- 工具链目录：`~/.espressif/tools/...`
- Python 环境：`~/.espressif/python_env/idf5.5_py3.9_env/...`

## 2.3 网络要求

构建时需要访问：

- GitHub（拉取 ESP-IDF 子模块）
- `dl.espressif.com` / `dl.espressif.cn` / PyPI（Python 依赖）

无网络会在 `set-target`/CMake 阶段卡住或失败。

## 3. 项目内配置参数（本次构建）

## 3.1 板型配置来源

文件：`main/boards/bread-compact-wifi/config.json`

- `target`: `esp32s3`
- `build name`: `bread-compact-wifi`
- `sdkconfig_append`: `CONFIG_OLED_SSD1306_128X32=y`

## 3.2 N16R8 资源相关默认配置

文件：`sdkconfig.defaults.esp32s3`

- `CONFIG_ESPTOOLPY_FLASHSIZE_16MB=y`
- `CONFIG_SPIRAM=y`
- `CONFIG_SPIRAM_MODE_OCT=y`

这些与 N16R8 资源规格匹配。

## 4. 构建命令（推荐顺序）

在仓库根目录执行：

```bash
cd /Users/feng/Work/xiaozhi-esp32

# 1) 加载 ESP-IDF 环境
. /tmp/esp-idf-v5.5.2/export.sh

# 2) 编译指定板型/变体
python3 scripts/release.py bread-compact-wifi --name bread-compact-wifi
```

## 5. 这次实际遇到的问题与处理

## 5.1 `idf.py: command not found`

原因：仅安装 VSCode 插件，不代表 shell 已有 ESP-IDF CLI。  
处理：按第 2.2 节安装并 `source export.sh`。

## 5.2 `Could not resolve host: github.com`（子模块下载失败）

原因：构建阶段网络受限。  
处理：开放网络后重试构建。

## 5.3 `build` 目录状态异常，`fullclean` 拒绝清理

现象：

```text
Directory '.../build' doesn't seem to be a CMake build directory
```

处理：

```bash
rm -rf build
```

然后重新执行构建命令。

## 5.4 `release.py` 提示某板卡 `config.json` 解析错误

现象（示例）：

```text
[ERROR] Failed to parse main/boards/freenove-esp32s3-display-2.8-lcd/config.json ...
```

说明：这是脚本扫描全板卡时的提示，**不影响当前指定板型的构建流程**。

## 5.5 已有同版本产物时会跳过

现象：

```text
Skipping bread-compact-wifi because releases/v2.2.5_bread-compact-wifi.zip already exists
```

若要强制重编：

```bash
rm -f releases/v2.2.5_bread-compact-wifi.zip
python3 scripts/release.py bread-compact-wifi --name bread-compact-wifi
```

## 6. 构建产物与校验

产物文件：

- `releases/v2.2.5_bread-compact-wifi.zip`
- zip 内含：`merged-binary.bin`

检查命令：

```bash
unzip -l releases/v2.2.5_bread-compact-wifi.zip
shasum -a 256 releases/v2.2.5_bread-compact-wifi.zip
```

本次构建得到的 SHA256：

```text
bd490ef6951fddad645f31910ac17f527912bc931c755b9c4095f75b95692845
```

## 7. 上传到开发板（烧录）

拿到 `releases/v2.2.5_bread-compact-wifi.zip` 后，推荐按下面步骤烧录。

## 7.1 解压固件包

```bash
unzip -o releases/v2.2.5_bread-compact-wifi.zip -d /tmp/xiaozhi-fw
```

解压后应有：

- `/tmp/xiaozhi-fw/merged-binary.bin`

## 7.2 连接开发板并确认串口

macOS：

```bash
ls /dev/cu.usb* /dev/cu.SLAB* 2>/dev/null
```

常见串口示例：

- `/dev/cu.usbmodemXXXX`
- `/dev/cu.SLAB_USBtoUART`

## 7.3 让开发板进入下载模式

大多数 ESP32-S3 开发板可用以下方式：

1. 按住 `BOOT`（有些板子是 `IO0`）
2. 短按一下 `RST`（或 `EN`）
3. 松开 `RST` 后再松开 `BOOT`

## 7.4 烧录 `merged-binary.bin`（整包地址 0x0）

将 `PORT` 替换成你的串口：

```bash
python -m esptool --chip esp32s3 --port PORT --baud 921600 write_flash -z 0x0 /tmp/xiaozhi-fw/merged-binary.bin
```

示例：

```bash
python -m esptool --chip esp32s3 --port /dev/cu.usbmodem5B901824481 --baud 921600 write_flash -z 0x0 /tmp/xiaozhi-fw/merged-binary.bin
```

## 7.5 常见失败与处理

- `Failed to connect` / 一直连不上：
  - 检查是否进入下载模式（重做 7.3）
  - 波特率从 `921600` 降到 `460800` 或 `115200`
- 串口占用（`Resource busy`）：
  - 关闭串口监视器（VSCode Monitor、`screen`、`miniterm`）
- 想彻底清空后重刷：

```bash
python -m esptool --chip esp32s3 --port PORT erase_flash
python -m esptool --chip esp32s3 --port PORT --baud 921600 write_flash -z 0x0 /tmp/xiaozhi-fw/merged-binary.bin
```

## 7.6 烧录后验证

- 观察串口日志是否正常启动（可用 `idf.py -p PORT monitor` 或 VSCode ESP-IDF Monitor）
- 首次启动通常需要重新配网（NVS 可能已被清空）

## 8. 一条命令复现（已安装好 ESP-IDF 前提下）

```bash
cd /Users/feng/Work/xiaozhi-esp32 && \
. /tmp/esp-idf-v5.5.2/export.sh && \
rm -rf build && \
rm -f releases/v2.2.5_bread-compact-wifi.zip && \
python3 scripts/release.py bread-compact-wifi --name bread-compact-wifi
```

---

如果你的实际硬件不是 `bread-compact-wifi` 这套引脚（例如摄像头板、圆屏板等），请先切换到对应板型再构建：

```bash
python3 scripts/release.py --list-boards
```
