# 基于 MCP 协议的 AI 语音聊天机器人

## 简介

👉 [人类：给 AI 装上摄像头 vs AI：瞬间发现主人三天没洗头【bilibili】](https://www.bilibili.com/video/BV1bpjgzKEhd/)

👉 [手搓 AI 女朋友，新手教程【bilibili】](https://www.bilibili.com/video/BV1XnmFYLEJN/)

小智 AI 语音聊天机器人作为一个语音交互入口，利用通义千问 / DeepSeek 等大模型的 AI 能力，并通过 MCP 协议实现多终端控制。

<img src="docs/mcp-based-graph.jpg" alt="通过 MCP 控制一切" width="320">

## 版本说明

当前 v2 版本与 v1 分区表不兼容，因此无法通过 OTA 从 v1 升级到 v2。分区表详情请参见 [partitions/v2/README.md](partitions/v2/README.md)。

所有运行 v1 的硬件都可以通过手动刷机升级到 v2。

v1 的稳定版本是 1.9.2。您可以通过运行 `git checkout v1` 切换到 v1。v1 分区将维护到 2026 年 2 月。

### 已实现功能

- Wi-Fi / ML307 Cat.1 4G 网络支持
- 离线语音唤醒 [ESP-SR](https://github.com/espressif/esp-sr)
- 支持两种通信协议（[Websocket](docs/websocket.md) 或 MQTT+UDP）
- 使用 OPUS 音频编解码
- 基于流式 ASR + LLM + TTS 架构的语音交互
- 说话人识别，识别当前说话人 [3D Speaker](https://github.com/modelscope/3D-Speaker)
- OLED / LCD 显示屏，支持表情显示
- 电池显示和电源管理
- 多语言支持（中文、英文、日文）
- 支持 ESP32-C3、ESP32-S3、ESP32-P4 芯片平台
- 设备端 MCP 用于设备控制（扬声器、LED、舵机、GPIO 等）
- 云端 MCP 用于扩展大模型能力（智能家居控制、PC 桌面操作、知识搜索、邮件等）
- 可自定义唤醒词、字体、表情和聊天背景，通过在线网页编辑（[自定义资源生成器](https://github.com/78/xiaozhi-assets-generator)）

## 硬件

### 面包板 DIY 实践

详见飞书文档教程：

👉 ["小智 AI 聊天机器人百科全书"](https://ccnphfhqs21z.feishu.cn/wiki/F5krwD16viZoF0kKkvDcrZNYnhb?from=from_copylink)

面包板演示：

![面包板演示](docs/v1/wiring2.jpg)

### 支持 70+ 开源硬件（部分列表）

- <a href="https://oshwhub.com/li-chuang-kai-fa-ban/li-chuang-shi-zhan-pai-esp32-s3-kai-fa-ban" target="_blank" title="立创 ESP32-S3 开发板">立创 ESP32-S3 开发板</a>
- <a href="https://github.com/espressif/esp-box" target="_blank" title="乐鑫 ESP32-S3-BOX3">乐鑫 ESP32-S3-BOX3</a>
- <a href="https://docs.m5stack.com/zh_CN/core/CoreS3" target="_blank" title="M5Stack CoreS3">M5Stack CoreS3</a>
- <a href="https://docs.m5stack.com/en/atom/Atomic%20Echo%20Base" target="_blank" title="AtomS3R + Echo Base">M5Stack AtomS3R + Echo Base</a>
- <a href="https://gf.bilibili.com/item/detail/1108782064" target="_blank" title="魔法按钮 2.4">魔法按钮 2.4</a>
- <a href="https://www.waveshare.net/shop/ESP32-S3-Touch-AMOLED-1.8.htm" target="_blank" title="微雪 ESP32-S3-Touch-AMOLED-1.8">微雪 ESP32-S3-Touch-AMOLED-1.8</a>
- <a href="https://github.com/Xinyuan-LilyGO/T-Circle-S3" target="_blank" title="LILYGO T-Circle-S3">LILYGO T-Circle-S3</a>
- <a href="https://oshwhub.com/tenclass01/xmini_c3" target="_blank" title="夏阁 Mini C3">夏阁 Mini C3</a>
- <a href="https://oshwhub.com/movecall/cuican-ai-pendant-lights-up-y" target="_blank" title="Movecall 璀璨 ESP32S3">璀璨 AI 项链</a>
- <a href="https://github.com/WMnologo/xingzhi-ai" target="_blank" title="WMnologo-Xingzhi-1.54">WMnologo-Xingzhi-1.54TFT</a>
- <a href="https://www.seeedstudio.com/SenseCAP-Watcher-W1-A-p-5979.html" target="_blank" title="SenseCAP Watcher">SenseCAP Watcher</a>
- <a href="https://www.bilibili.com/video/BV1BHJtz6E2S/" target="_blank" title="ESP-HI 低成本机器狗">ESP-HI 低成本机器狗</a>

<div style="display: flex; justify-content: space-between;">
  <a href="docs/v1/lichuang-s3.jpg" target="_blank" title="立创 ESP32-S3 开发板">
    <img src="docs/v1/lichuang-s3.jpg" width="240" />
  </a>
  <a href="docs/v1/espbox3.jpg" target="_blank" title="乐鑫 ESP32-S3-BOX3">
    <img src="docs/v1/espbox3.jpg" width="240" />
  </a>
  <a href="docs/v1/m5cores3.jpg" target="_blank" title="M5Stack CoreS3">
    <img src="docs/v1/m5cores3.jpg" width="240" />
  </a>
  <a href="docs/v1/atoms3r.jpg" target="_blank" title="AtomS3R + Echo Base">
    <img src="docs/v1/atoms3r.jpg" width="240" />
  </a>
  <a href="docs/v1/magiclick.jpg" target="_blank" title="魔法按钮 2.4">
    <img src="docs/v1/magiclick.jpg" width="240" />
  </a>
  <a href="docs/v1/waveshare.jpg" target="_blank" title="微雪 ESP32-S3-Touch-AMOLED-1.8">
    <img src="docs/v1/waveshare.jpg" width="240" />
  </a>
  <a href="docs/v1/lilygo-t-circle-s3.jpg" target="_blank" title="LILYGO T-Circle-S3">
    <img src="docs/v1/lilygo-t-circle-s3.jpg" width="240" />
  </a>
  <a href="docs/v1/xmini-c3.jpg" target="_blank" title="夏阁 Mini C3">
    <img src="docs/v1/xmini-c3.jpg" width="240" />
  </a>
  <a href="docs/v1/movecall-cuican-esp32s3.jpg" target="_blank" title="璀璨">
    <img src="docs/v1/movecall-cuican-esp32s3.jpg" width="240" />
  </a>
  <a href="docs/v1/wmnologo_xingzhi_1.54.jpg" target="_blank" title="WMnologo-Xingzhi-1.54">
    <img src="docs/v1/wmnologo_xingzhi_1.54.jpg" width="240" />
  </a>
  <a href="docs/v1/sensecap_watcher.jpg" target="_blank" title="SenseCAP Watcher">
    <img src="docs/v1/sensecap_watcher.jpg" width="240" />
  </a>
  <a href="docs/v1/esp-hi.jpg" target="_blank" title="ESP-HI 低成本机器狗">
    <img src="docs/v1/esp-hi.jpg" width="240" />
  </a>
</div>

## 软件

### 固件刷机

对于初学者，建议使用可以直接刷机而无需搭建开发环境的固件。

固件默认连接到官方 [xiaozhi.me](https://xiaozhi.me) 服务器。个人用户可以注册账户免费使用通义千问实时模型。

👉 [新手固件刷机指南](https://ccnphfhqs21z.feishu.cn/wiki/Zpz4wXBtdimBrLk25WdcXzxcnNS)

### 开发环境

- Cursor 或 VSCode
- 安装 ESP-IDF 插件，选择 SDK 版本 5.4 或以上
- Linux 比 Windows 更好，编译速度更快，驱动问题更少
- 本项目使用 Google C++ 代码风格，提交代码时请确保符合规范

### 开发者文档

- [自定义开发板指南](docs/custom-board.md) - 学习如何为小智 AI 创建自定义开发板
- [MCP 协议 IoT 控制使用](docs/mcp-usage.md) - 学习如何通过 MCP 协议控制 IoT 设备
- [MCP 协议交互流程](docs/mcp-protocol.md) - 设备端 MCP 协议实现
- [MQTT + UDP 混合通信协议文档](docs/mqtt-udp.md)
- [详细的 WebSocket 通信协议文档](docs/websocket.md)
- [源码工作流程图与模块图](docs/source-flow-and-modules.md) - 基于源码分析的全链路流程图与架构模块图
- [ESP32-S3 N16R8 编译构建指南](docs/build-esp32s3-n16r8.md) - 针对 ESP32-S3 N16R8 开发板的构建步骤

## 大模型配置

如果您已经拥有小智 AI 聊天机器人设备并已连接到官方服务器，可以登录 [xiaozhi.me](https://xiaozhi.me) 控制台进行配置。

👉 [后台操作视频教程（旧界面）](https://www.bilibili.com/video/BV1jUCUY2EKM/)

## 相关开源项目

个人电脑上的服务器部署，请参考以下开源项目：

- [xinnan-tech/xiaozhi-esp32-server](https://github.com/xinnan-tech/xiaozhi-esp32-server) Python 服务器
- [joey-zhou/xiaozhi-esp32-server-java](https://github.com/joey-zhou/xiaozhi-esp32-server-java) Java 服务器
- [AnimeAIChat/xiaozhi-server-go](https://github.com/AnimeAIChat/xiaozhi-server-go) Golang 服务器
- [hackers365/xiaozhi-esp32-server-golang](https://github.com/hackers365/xiaozhi-esp32-server-golang) Golang 服务器

其他使用小智通信协议的客户端项目：

- [huangjunsen0406/py-xiaozhi](https://github.com/huangjunsen0406/py-xiaozhi) Python 客户端
- [TOM88812/xiaozhi-android-client](https://github.com/TOM88812/xiaozhi-android-client) Android 客户端
- [100askTeam/xiaozhi-linux](http://github.com/100askTeam/xiaozhi-linux) 百问网提供的 Linux 客户端
- [78/xiaozhi-sf32](https://github.com/78/xiaozhi-sf32) 四川提供的蓝牙芯片固件
- [QuecPython/solution-xiaozhiAI](https://github.com/QuecPython/solution-xiaozhiAI) 移远提供的 QuecPython 固件

自定义资源工具：

- [78/xiaozhi-assets-generator](https://github.com/78/xiaozhi-assets-generator) 自定义资源生成器（唤醒词、字体、表情、背景）

## 关于项目

这是一个开源的 ESP32 项目，采用 MIT 许可证发布，允许任何人免费使用，包括商业用途。

我们希望这个项目能帮助大家了解 AI 硬件开发，并将快速发展的大语言模型应用到实际的硬件设备中。

如果您有任何想法或建议，欢迎提出 Issues 或加入我们的 [Discord](https://discord.gg/C759fGMBcZ) 或 QQ 群：994694848

## Star 历史

<a href="https://star-history.com/#78/xiaozhi-esp32&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=78/xiaozhi-esp32&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=78/xiaozhi-esp32&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=78/xiaozhi-esp32&type=Date" />
 </picture>
</a>
