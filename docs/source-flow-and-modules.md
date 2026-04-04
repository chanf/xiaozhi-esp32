# 小智AI 源码分析图（Mermaid）

## 1. 分析范围与方法
- 范围：基于当前仓库 `main/` 全量源码，重点覆盖启动、网络、激活、协议、音频、状态机、MCP、OTA、板级抽象与板型扩展。
- 方法：先做目录级全扫描，再按主调用链追踪关键入口与回调（`main.cc -> Application -> Board/Audio/Protocol/Ota/Mcp`），最后对照实现文件补齐异常分支与恢复分支。
- 目标：输出两张图。
  - 工作流程图：全链路主流程（上电到会话、异常恢复、升级重启）。
  - 模块图：核心层 + 扩展层（聚合板型，不逐个展开 90+ 板目录）。

## 2. Mermaid 工作流程图（全链路）
```mermaid
flowchart TD
    A[app_main 启动] --> B[NVS 初始化/修复]
    B --> C[Application::Initialize]

    C --> C1[Board::GetInstance]
    C --> C2[Display.SetupUI + 版本信息]
    C --> C3[AudioService.Initialize + Start]
    C --> C4[注册 Audio 回调与 State 回调]
    C --> C5[McpServer.AddCommonTools/UserOnlyTools]
    C --> C6[Board.SetNetworkEventCallback]
    C --> C7[Board.StartNetwork 异步联网]
    C --> D[Application::Run 事件循环]

    D --> E{网络事件}
    E -->|Connected| F[HandleNetworkConnectedEvent]
    E -->|Disconnected| G[HandleNetworkDisconnectedEvent]

    F --> H[状态 -> Activating]
    H --> I[创建 ActivationTask]
    I --> J[CheckAssetsVersion]
    J --> K[CheckNewVersion]
    K --> L[InitializeProtocol]
    L --> M{OTA 配置含协议?}
    M -->|mqtt| N[MqttProtocol]
    M -->|websocket| O[WebsocketProtocol]
    M -->|默认| N
    N --> P[protocol.Start]
    O --> P
    P --> Q[MAIN_EVENT_ACTIVATION_DONE]
    Q --> R[HandleActivationDoneEvent]
    R --> S[状态 -> Idle, 播放成功音, 低功耗]

    D --> T{用户输入/唤醒词}
    T -->|按键 Toggle/Start/Stop| U[聊天状态控制]
    T -->|Wake Word| V[HandleWakeWordDetectedEvent]
    U --> W[必要时 OpenAudioChannel]
    V --> W
    W --> X[状态 -> Listening]

    D --> Y[MAIN_EVENT_SEND_AUDIO]
    X --> Y
    Y --> Z[AudioService PopSendQueue]
    Z --> AA[protocol.SendAudio 上行]

    P --> AB[协议下行消息回调]
    AB --> AC{消息类型}
    AC -->|tts start/stop| AD[Speaking 与 Listening/Idle 状态切换]
    AC -->|stt/llm| AE[Display 文本/情绪更新]
    AC -->|mcp| AF[McpServer.ParseMessage]
    AC -->|system/alert| AG[Reboot/Alert 等系统行为]
    AB --> AH[协议下行音频]
    AH --> AI[AudioService.PushDecodeQueue]
    AI --> AJ[Opus 解码 + 扬声器播放]

    D --> AK{异常与恢复}
    AK -->|网络断开| G
    G --> G1[会话中则 CloseAudioChannel]
    G1 --> G2[状态栏更新，等待重连]
    AK -->|协议错误/超时| AL[MAIN_EVENT_ERROR]
    AL --> AM[Alert + 状态回 Idle]
    AK -->|Server goodbye/断链| AN[OnAudioChannelClosed]
    AN --> AO[清理 UI + 状态回 Idle]

    K --> AP{发现新固件?}
    AP -->|是| AQ[UpgradeFirmware]
    AQ --> AR[关闭通道/停音频/下载写入 OTA]
    AR --> AS{升级成功?}
    AS -->|是| AT[Reboot -> esp_restart]
    AS -->|否| AU[重启音频并继续运行]
    AP -->|否| S

    AO --> END1[终点A: 正常会话结束(Idle)]
    AM --> END2[终点B: 异常恢复后待机(Idle)]
    AT --> END3[终点C: OTA升级重启]
```

## 3. Mermaid 模块图（核心层 + 扩展层）
```mermaid
flowchart TB
    subgraph L1[应用编排层]
        APP[Application]
        DSM[DeviceStateMachine]
    end

    subgraph L2[服务层]
        ASVC[AudioService]
        OTA[Ota]
        AST[Assets]
        MCP[McpServer]
        SET[Settings/NVS]
        SYS[SystemInfo]
    end

    subgraph L3[协议层]
        PABS[Protocol 抽象]
        PMQTT[MqttProtocol]
        PWS[WebsocketProtocol]
    end

    subgraph L4[板级抽象层]
        BOARD[Board 抽象]
        WBOARD[WifiBoard]
        NET[NetworkInterface<br/>HTTP/WebSocket/MQTT/UDP]
        DISP[Display]
        CODEC[AudioCodec]
        LED[Led]
        CAM[Camera(可选)]
    end

    subgraph L5[板级实现扩展层]
        BIG[Board Implementations Group<br/>main/boards/* (90+)]
        CUR[当前配置示例: bread-compact-wifi]
    end

    APP -->|状态迁移请求| DSM
    DSM -->|状态变更回调事件| APP

    APP -->|初始化/控制| ASVC
    APP -->|激活/版本/升级| OTA
    APP -->|资源检查/下载/应用| AST
    APP -->|注册工具/转发MCP消息| MCP
    APP -->|读取设备与编译信息| SYS
    APP -->|读写配置| SET

    APP -->|协议实例化与回调绑定| PABS
    PMQTT -->|实现| PABS
    PWS -->|实现| PABS

    APP -->|获取硬件能力| BOARD
    BOARD --> WBOARD
    BOARD --> DISP
    BOARD --> CODEC
    BOARD --> LED
    BOARD --> CAM
    BOARD --> NET

    OTA -->|HTTP检查版本/下载固件| NET
    AST -->|HTTP下载资产| NET
    PMQTT -->|MQTT信令 + UDP音频| NET
    PWS -->|WebSocket信令+音频| NET

    ASVC -->|采集/播放/编解码| CODEC
    APP -->|UI更新| DISP
    APP -->|状态灯联动| LED
    MCP -->|设备控制工具调用| BOARD
    MCP -->|通过 Application 发回协议| APP

    BIG --> CUR
    CUR -->|继承/实现| WBOARD
```

## 4. 图例与边关系说明（调用/事件/数据流）
- 节点含义
  - 矩形节点：模块、类或阶段动作。
  - 菱形节点：条件分支或协议选择点。
  - `END*`：流程终点。
- 边类型
  - 调用流：`A --> B`，表示同步调用或直接控制关系。
  - 事件流：边标签含“事件/回调/状态变更”，表示异步触发（例如 EventGroup bit、网络回调、协议回调）。
  - 数据流：边标签含“上行/下行/下载/写入”，表示音频帧、JSON、资源或固件数据传输。
- 主流程约束
  - 启动后必须进入 `Application::Run` 事件循环。
  - 会话主链路以 `OpenAudioChannel -> Listening -> Send/Receive -> Idle` 闭环。
  - 异常分支统一回收到 Idle（可再次发起会话）。
  - OTA 成功分支以重启作为终止点。

## 5. 关键源码锚点（用于追溯图中节点）
- 启动与入口
  - `main/main.cc`
  - `main/application.h`
  - `main/application.cc`
- 事件循环与状态机
  - `main/device_state.h`
  - `main/device_state_machine.h`
  - `main/device_state_machine.cc`
- 音频链路
  - `main/audio/audio_service.h`
  - `main/audio/audio_service.cc`
- 协议抽象与实现
  - `main/protocols/protocol.h`
  - `main/protocols/protocol.cc`
  - `main/protocols/mqtt_protocol.h`
  - `main/protocols/mqtt_protocol.cc`
  - `main/protocols/websocket_protocol.h`
  - `main/protocols/websocket_protocol.cc`
- 板级抽象与网络配置
  - `main/boards/common/board.h`
  - `main/boards/common/board.cc`
  - `main/boards/common/wifi_board.h`
  - `main/boards/common/wifi_board.cc`
  - `main/boards/bread-compact-wifi/compact_wifi_board.cc`
- OTA、资源、配置、MCP
  - `main/ota.h`
  - `main/ota.cc`
  - `main/assets.h`
  - `main/assets.cc`
  - `main/settings.h`
  - `main/settings.cc`
  - `main/mcp_server.h`
  - `main/mcp_server.cc`
- 组件装配与板型聚合入口
  - `main/CMakeLists.txt`
