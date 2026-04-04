# 小智AI 屏幕支持实现与支持列表（源码扫描）

> 统计基线：当前仓库 `main/boards` 下所有含 `config.json` 的板型目录（共 120 个），统计日期：2026-04-04。

## 1. 屏幕支持是如何实现的

### 1.1 显示抽象层
- 通用显示接口在 `Display` 抽象类：`main/display/display.h`。
- 默认兜底实现为 `NoDisplay`：`main/display/display.h`、`main/boards/common/board.cc`。

关键点：
- `Board::GetDisplay()` 是板级统一入口（虚函数）：`main/boards/common/board.h`。
- 如果板型未覆写 `GetDisplay()`，会返回默认 `NoDisplay`：`main/boards/common/board.cc`。

### 1.2 应用启动时绑定显示
- 应用初始化时，会调用板级显示并初始化 UI：
  - `Application::Initialize()` -> `board.GetDisplay()` -> `display->SetupUI()`  
  - 位置：`main/application.cc`。

### 1.3 标准显示实现
- OLED：`OledDisplay`（`main/display/oled_display.h`）
- LCD 基类：`LcdDisplay`（`main/display/lcd_display.h`）
  - SPI LCD：`SpiLcdDisplay`
  - RGB LCD：`RgbLcdDisplay`
  - MIPI LCD：`MipiLcdDisplay`
- 表情动画屏：`EmoteDisplay`（`main/display/emote_display.h`）

### 1.4 板型决定具体屏幕实现
- 每个板型在 `main/boards/<board>/` 中初始化自己的显示驱动，并在 `GetDisplay()` 返回具体对象。
- 构建阶段由 `CONFIG_BOARD_TYPE_*` 决定编译哪个板型代码：`main/CMakeLists.txt`。

---

## 2. 屏幕支持概览（按板型统计）

| 类型 | 数量 | 说明 |
| --- | ---: | --- |
| OLED | 13 | 直接使用 `OledDisplay` |
| SPI LCD | 77 | 直接使用 `SpiLcdDisplay` |
| RGB LCD | 5 | 直接使用 `RgbLcdDisplay` |
| MIPI LCD | 5 | 直接使用 `MipiLcdDisplay` |
| EmoteDisplay | 5 | 使用表情动画显示管线 |
| E-Paper | 2 | 电子纸相关实现 |
| NoDisplay（显式） | 1 | 板型显式返回 `NoDisplay` |
| NoDisplay（默认兜底） | 7 | 板型未覆写 `GetDisplay()`，走默认 `NoDisplay` |
| 自定义显示实现 | 5 | 板型自定义 Display/LcdDisplay 子类（不直接命中标准分类） |

总计：120

---

## 3. 板型支持列表

### 3.1 OLED（13）

```text
bread-compact-esp32
bread-compact-ml307
bread-compact-nt26
bread-compact-wifi
hu-087
kevin-box-2
lceda-course-examples/eda-robot-pro
tudouzi
xingzhi-cube-0.96oled-ml307
xingzhi-cube-0.96oled-wifi
xmini-c3
xmini-c3-4g
xmini-c3-v3
```

### 3.2 SPI LCD（77）

```text
aipi-lite
atk-dnesp32s3
atk-dnesp32s3-box
atk-dnesp32s3-box0
atk-dnesp32s3-box2-4g
atk-dnesp32s3-box2-wifi
atoms3-echo-base
atoms3r-echo-base
bread-compact-esp32-lcd
df-k10
du-chatx
electron-bot
esp-box-lite
esp-sparkbot
esp32-cgc
esp32-cgc-144
esp32s3-korvo2-v3
esp32s3-korvo2-v3-rndis
freenove-esp32s3-display-2.8-lcd
genjutech-s3-1.54tft
jiuchuan-s3
kevin-sp-v4-dev
labplus-ledong-v2
labplus-mpython-v3
lceda-course-examples/eda-tv-pro
lichuang-c3-dev
lilygo-t-cameraplus-s3
lilygo-t-circle-s3
lilygo-t-display-s3-pro-mvsrlora
m5stack-cardputer-adv
m5stack-core-s3
magiclick-2p4
magiclick-2p5
magiclick-c3
magiclick-c3-v2
minsi-k08-dual
mixgo-nova
movecall-cuican-esp32s3
movecall-moji-esp32s3
movecall-moji2-esp32c5
otto-robot
sensecap-watcher
sp-esp32-s3-1.28-box
sp-esp32-s3-1.54-muma
surfer-c3-1.14tft
taiji-pi-s3
waveshare/esp32-c6-lcd-1.69
waveshare/esp32-c6-touch-amoled-1.32
waveshare/esp32-c6-touch-amoled-1.43
waveshare/esp32-c6-touch-amoled-1.8
waveshare/esp32-c6-touch-amoled-2.06
waveshare/esp32-c6-touch-amoled-2.16
waveshare/esp32-c6-touch-lcd-1.83
waveshare/esp32-p4-wifi6-touch-lcd-3.5
waveshare/esp32-s3-audio-board
waveshare/esp32-s3-lcd-0.85
waveshare/esp32-s3-touch-amoled-1.32
waveshare/esp32-s3-touch-amoled-1.75
waveshare/esp32-s3-touch-amoled-1.8
waveshare/esp32-s3-touch-amoled-2.06
waveshare/esp32-s3-touch-lcd-1.46
waveshare/esp32-s3-touch-lcd-1.54
waveshare/esp32-s3-touch-lcd-1.83
waveshare/esp32-s3-touch-lcd-1.85
waveshare/esp32-s3-touch-lcd-1.85c
waveshare/esp32-s3-touch-lcd-3.5
waveshare/esp32-touch-lcd-3.5
xingzhi-abs-2.0
xingzhi-cube-0.85tft-ml307
xingzhi-cube-0.85tft-wifi
xingzhi-cube-1.54tft-ml307
xingzhi-cube-1.54tft-wifi
xingzhi-metal-1.54-wifi
yunliao-s3
zhengchen-1.54tft-wifi
zhengchen-cam
zhengchen-cam-ml307
```

### 3.3 RGB LCD（5）

```text
esp-s3-lcd-ev-board
esp-s3-lcd-ev-board-2
kevin-yuying-313lcd
waveshare/esp32-s3-touch-lcd-4.3c
waveshare/esp32-s3-touch-lcd-4b
```

### 3.4 MIPI LCD（5）

```text
esp-p4-function-ev-board
m5stack-tab5
waveshare/esp32-p4-nano
waveshare/esp32-p4-wifi6-touch-lcd
wireless-tag-wtp4c5mp07s
```

### 3.5 EmoteDisplay（5）

```text
esp-box
esp-box-3
esp-sensairshuttle
esp-vocat
lichuang-dev
```

### 3.6 E-Paper（2）

```text
waveshare/esp32-s3-epaper-1.54
waveshare/esp32-s3-epaper-3.97
```

### 3.7 NoDisplay（显式，1）

```text
lceda-course-examples/eda-super-bear
```

### 3.8 NoDisplay（默认兜底，7）

```text
atom-echos3r
atommatrix-echo-base
atoms3r-cam-m12-echo-base
df-s3-ai-cam
doit-s3-aibox
esp-spot
kevin-c3
```

### 3.9 自定义显示实现（5）

```text
esp-hi
waveshare/esp32-s3-rlcd-4.2
waveshare/esp32-s3-touch-lcd-3.49
waveshare/esp32-s3-touch-lcd-3.5b
zhengchen-1.54tft-ml307
```

说明：
- 以上板型在板级目录里使用了自定义 `Display/LcdDisplay` 子类，或显示逻辑跨目录复用，不直接落在标准 `Oled/Spi/Rgb/Mipi` 关键词匹配中。

---

## 4. 关键源码锚点（便于追溯）

- 应用初始化显示：
  - `main/application.cc` (`Application::Initialize`)
- 显示抽象与兜底：
  - `main/display/display.h` (`Display`, `NoDisplay`)
  - `main/boards/common/board.h` (`virtual Display* GetDisplay()`)
  - `main/boards/common/board.cc` (`Board::GetDisplay -> static NoDisplay`)
- 标准显示实现：
  - `main/display/oled_display.h`
  - `main/display/lcd_display.h`
  - `main/display/emote_display.h`
- 板型编译选择：
  - `main/CMakeLists.txt` (`CONFIG_BOARD_TYPE_*`)

---

## 5. 维护说明

- 该列表为“源码扫描结果”，会随板型新增/修改变化。
- 如果你希望，我可以再给你加一个脚本（如 `scripts/report_display_support.py`），一键重新生成这份列表，避免手工维护。
