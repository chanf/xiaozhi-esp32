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
    A[app_main 启动]
    B[NVS 初始化与修复]
    C[Application Initialize]
    A --> B --> C

    C1[Board 与 Display 初始化]
    C2[AudioService 初始化并启动]
    C3[McpServer 注册工具]
    C4[注册网络与音频回调]
    D[Board 异步联网]
    E[Application Run 事件循环]
    C --> C1
    C --> C2
    C --> C3
    C --> C4
    C --> D
    C --> E

    F{网络是否已连接}
    E --> F
    F -->|是| G[进入 Activating 并启动 ActivationTask]
    F -->|否| H[等待网络或进入配网]

    I[检查 Assets 版本并应用]
    J[检查固件版本与激活状态]
    L{选择协议}
    M[MqttProtocol]
    N[WebsocketProtocol]
    K[初始化协议并启动]
    O[Activation 完成并进入 Idle]
    G --> I --> J --> L
    L -->|MQTT| M
    L -->|WebSocket| N
    M --> K
    N --> K
    K --> O

    P{用户交互}
    Q[按键触发聊天状态控制]
    R[唤醒词触发唤醒处理]
    S[必要时打开音频通道]
    T[进入 Listening]
    E --> P
    P --> Q
    P --> R
    Q --> S
    R --> S
    S --> T

    U[发送上行音频]
    V[接收下行消息与音频]
    W[Protocol SendAudio]
    X[更新文本 情绪 MCP 指令]
    Y[音频解码与播放]
    Z[Speaking 与 Listening 或 Idle 切换]
    T --> U
    U --> W
    K --> V
    V --> X
    V --> Y
    Y --> Z

    AA{异常处理}
    AB[关闭音频通道并等待重连]
    AC[告警并回到 Idle]
    AD[清理 UI 并回到 Idle]
    E --> AA
    AA -->|断网| AB
    AA -->|协议错误或超时| AC
    AA -->|服务端关闭会话| AD

    AE{是否发现新固件}
    AF[执行 OTA 下载与写入]
    AG{升级是否成功}
    AH[重启设备]
    AI[恢复音频并继续运行]
    J --> AE
    AE -->|是| AF
    AF --> AG
    AG -->|是| AH
    AG -->|否| AI
    AE -->|否| O

    O --> END1[终点 正常会话结束]
    AC --> END2[终点 异常恢复待机]
    AD --> END2
    AH --> END3[终点 OTA 重启]
```

## 3. Mermaid 模块图（核心层 + 扩展层）
```mermaid
flowchart TB
    subgraph 应用编排层
        APP[Application]
        DSM[DeviceStateMachine]
    end

    subgraph 服务层
        ASVC[AudioService]
        OTA[Ota]
        AST[Assets]
        MCP[McpServer]
        SET[Settings]
        SYS[SystemInfo]
    end

    subgraph 协议层
        PABS[Protocol 抽象]
        PMQTT[MqttProtocol]
        PWS[WebsocketProtocol]
    end

    subgraph 板级抽象层
        BOARD[Board 抽象]
        WBOARD[WifiBoard]
        NET[NetworkInterface]
        DISP[Display]
        CODEC[AudioCodec]
        LED[Led]
        CAM[Camera 可选]
    end

    subgraph 网络通道
        HTTP[HTTP]
        MQ[MQTT]
        WS[WebSocket]
        UDP[UDP]
    end

    subgraph 板级实现扩展层
        BIG[Board Implementations Group]
        CUR[当前配置示例 bread compact wifi]
    end

    APP -->|状态迁移请求| DSM
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
    NET --> HTTP
    NET --> MQ
    NET --> WS
    NET --> UDP

    ASVC -->|采集/播放/编解码| CODEC
    APP --> DISP
    APP --> LED
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
