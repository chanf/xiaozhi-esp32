# 小智AI 与 LLM 通讯链路（设备-服务端-模型）

本文基于当前固件源码整理：设备端不直接调用大模型 API，而是先与业务服务端建立会话通道，由服务端完成 STT/LLM/TTS 编排，再把结果回传设备。

## 1. 系统全局结构图

```mermaid
graph LR
    Device["小智AI（设备固件）"]
    Activate["激活/配置/版本服务"]
    Gateway["会话通信网关"]
    LLM["LLM 服务器"]
    STT["STT 服务"]
    TTS["TTS 服务"]
    MCP["工具编排/MCP 调用层"]
    FW["固件下载服务"]
    Assets["资源包下载服务"]
    Vision["视觉/图像理解 HTTP 服务"]
    ScreenSvc["屏幕快照上传/预览图片 URL 服务"]

    Device -->|HTTP checkVersion / activate| Activate
    Activate -->|下发 websocket / mqtt 配置与鉴权信息| Device

    Device -->|上行会话消息/音频| Gateway
    Gateway -->|下行会话消息/音频| Device
    Gateway -->|语音上行| STT
    STT -->|识别文本| Gateway

    Gateway -->|Prompt 与上下文| LLM
    LLM -->|回复文本/情绪/工具意图| Gateway

    Gateway -->|待合成文本| TTS
    TTS -->|TTS 音频流| Gateway

    LLM -->|触发工具调用| MCP
    MCP -->|工具执行结果| LLM
    MCP -->|MCP JSON-RPC 透传结果| Gateway
    Gateway -->|MCP JSON-RPC 请求| MCP
    Gateway -->|type mcp payload| Device
    Device -->|type mcp payload| Gateway

    Device -->|HTTP 下载 firmware| FW
    Device -->|HTTP 下载 assets| Assets
    Device -->|HTTP 上传图片并提问| Vision
    Device -->|HTTP 上传快照| ScreenSvc
    ScreenSvc -->|HTTP 预览图 URL/内容| Device
```

## 2. 全链路时序图（WebSocket 主路径）

```mermaid
sequenceDiagram
    autonumber
    participant Device as ESP32 Device
    participant Backend as Backend API
    participant STT as STT Service
    participant LLM as LLM Service
    participant TTS as TTS Service

    Note over Device,Backend: 1) 会话建立
    Device->>Backend: WebSocket Connect + Headers(Authorization, Protocol-Version, Device-Id, Client-Id)
    Device->>Backend: {"type":"hello","version":n,"transport":"websocket","audio_params":...,"features":{"mcp":true}}
    Backend-->>Device: {"type":"hello","session_id":"...","transport":"websocket","audio_params":...}

    Note over Device,Backend: 2) 开始监听
    Device->>Backend: {"session_id":"...","type":"listen","state":"start","mode":"auto|manual|realtime"}
    loop 用户说话期间
        Device->>Backend: Binary Opus Audio Frame
    end

    Note over Backend,STT: 3) 语音识别
    Backend->>STT: Streaming Audio
    STT-->>Backend: Partial/Final Text
    Backend-->>Device: {"session_id":"...","type":"stt","text":"..."}

    Note over Backend,LLM: 4) 大模型推理
    Backend->>LLM: Prompt(ASR 文本 + 上下文 + 工具状态)
    LLM-->>Backend: Answer + Emotion + Optional Tool Call
    Backend-->>Device: {"session_id":"...","type":"llm","emotion":"..."}

    Note over Backend,TTS: 5) 语音合成
    Backend->>TTS: Text to Speech
    Backend-->>Device: {"session_id":"...","type":"tts","state":"start"}
    loop 播放期间
        Backend-->>Device: Binary Opus Audio Frame
    end
    Backend-->>Device: {"session_id":"...","type":"tts","state":"sentence_start","text":"..."}
    Backend-->>Device: {"session_id":"...","type":"tts","state":"stop"}

    opt MCP 工具调用
        Backend-->>Device: {"session_id":"...","type":"mcp","payload":{"jsonrpc":"2.0","id":1,"method":"tools/call","params":...}}
        Device-->>Backend: {"session_id":"...","type":"mcp","payload":{"jsonrpc":"2.0","id":1,"result":...}}
    end

    Note over Device,Backend: 6) 会话结束
    Device->>Backend: {"session_id":"...","type":"listen","state":"stop"} or {"session_id":"...","type":"abort"}
```

## 3. MQTT+UDP 变体（差异点）

- 控制面：走 MQTT（`hello/listen/stt/tts/mcp/goodbye` 这类 JSON）。
- 媒体面：走 UDP（Opus 音频，AES-CTR 加密，含 `nonce/sequence/timestamp`）。
- 建链过程：设备先 MQTT 发送 `hello(transport=udp)`，服务端回 `udp.server/port/key/nonce`，再建立 UDP 音频通道。

## 4. 关键消息清单

- 设备上行
  - `type=hello`
  - `type=listen, state=start|stop|detect`
  - `type=abort`
  - `type=mcp`
  - Binary Opus Audio
- 服务端下行
  - `type=hello`
  - `type=stt`
  - `type=tts, state=start|sentence_start|stop`
  - `type=llm`（如 `emotion`）
  - `type=mcp`
  - `type=system`（如 `reboot`）
  - Binary Opus Audio

## 5. 对应源码锚点

- 协议抽象与消息发送：`main/protocols/protocol.h`, `main/protocols/protocol.cc`
- WebSocket 实现：`main/protocols/websocket_protocol.cc`
- MQTT+UDP 实现：`main/protocols/mqtt_protocol.cc`
- 消息分发与状态机：`main/application.cc`
- 音频编解码流水线：`main/audio/audio_service.h`, `main/audio/audio_service.cc`
- MCP 消息处理：`main/mcp_server.cc`
- 协议配置来源（OTA 下发并写入 settings）：`main/ota.cc`
