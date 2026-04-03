# ESP-P4-Function-EV-Board

支持 ESP-P4-Function-EV-Board 开发板。Wi‑Fi 通过板载 ESP32‑C6 使用 ESP‑Hosted 连接。LCD 通过官方 MIPI‑DSI LCD 适配器支持。

## 功能特性
- **Wi‑Fi**：`esp_wifi_remote` + `esp_hosted` (SDIO)，使用 ESP32‑C6 协处理器
- **显示屏**：通过适配器连接的 7 英寸 MIPI‑DSI LCD（1024×600）；也可以无屏运行
- **音频**：ES8311 编解码器，支持扬声器和麦克风
- **触摸**：GT911 电容式触摸控制器
- **SD 卡**：MicroSD 卡支持（MMC 模式）
- **摄像头**：MIPI-CSI 摄像头接口，具有回退 DVP 配置（支持 OV5647、SC2336 传感器）
- **USB**：USB 主机/设备支持
- **SPIFFS**：内置 Flash 文件系统支持
- **字体**：自定义字体支持，具有 Unicode 字符（越南语、中文等）

## 配置
在 `menuconfig` 中：Xiaozhi Assistant -> Board Type -> ESP-P4-Function-EV-Board

确保设置了以下选项（通过 config.json 构建时会自动设置）：
- `CONFIG_SLAVE_IDF_TARGET_ESP32C6=y`
- `CONFIG_ESP_HOSTED_P4_DEV_BOARD_FUNC_BOARD=y`
- `CONFIG_ESP_HOSTED_SDIO_HOST_INTERFACE=y`
- `CONFIG_ESP_HOSTED_SDIO_4_BIT_BUS=y`

## LCD 连接（来自乐鑫用户指南）
- 将 LCD 适配器板 J3 连接到板子的 MIPI DSI 连接器（反向排线）。
- 将 `RST_LCD`（适配器 J6）连接到 `GPIO27`（板子 J1）。
- 将 `PWM`（适配器 J6）连接到 `GPIO26`（板子 J1）。
- 可选择通过适配器的 USB 为 LCD 适配器供电，或从板子提供 `5V` 和 `GND`。

这些引脚在 `config.h` 中预配置为 `PIN_NUM_LCD_RST=GPIO27` 和 `DISPLAY_BACKLIGHT_PIN=GPIO26`。分辨率设置为 1024×600。

## 构建示例
```powershell
idf.py set-target esp32p4
idf.py menuconfig
idf.py build
```

提示：在 menuconfig 中，选择 Xiaozhi Assistant -> Board Type -> ESP-P4-Function-EV-Board。
如果通过脚本构建发布版，此文件夹中的 `config.json` 会附加所需的 Hosted 选项。
