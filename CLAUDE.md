# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

XiaoZhi (小智) is an ESP32-based AI voice chatbot that leverages large language models (Qwen, DeepSeek) and uses the MCP (Model Context Protocol) for multi-terminal control. The project supports 70+ hardware boards with Wi-Fi or 4G connectivity, offline wake word detection, streaming ASR+LLM+TTS architecture, and multi-language support.

## Build and Development Commands

### Prerequisites
- ESP-IDF 5.4 or above (install via VSCode/ESP-IDF extension)
- Python 3.x
- clang-format (for code formatting)

### Basic Build Commands
```bash
# Set target chip (required on first build or when changing targets)
idf.py set-target esp32s3    # or esp32c3, esp32p4, etc.

# Clean build
idf.py fullclean

# Configure board type via menuconfig
idf.py menuconfig
# Navigate to: Xiaozhi Assistant -> Board Type

# Build firmware
idf.py build

# Flash and monitor
idf.py flash monitor

# Merge binary for OTA distribution
idf.py merge-bin
```

### Board-Specific Build (Recommended)
```bash
# Build and package firmware for a specific board
python scripts/release.py <board-directory-name>
# Example: python scripts/release.py esp-box-3

# This script automatically:
# - Reads config.json for target chip and build options
# - Applies sdkconfig_append settings
# - Builds and packages firmware to releases/
```

### Code Formatting
```bash
# Format single file
clang-format -i path/to/file.cc

# Format entire project
find main -iname *.h -o -iname *..cc | xargs clang-format -i

# Check format without modifying
clang-format --dry-run -Werror path/to/file.cc
```

## Architecture Overview

### Board Abstraction Layer
All boards inherit from the `Board` base class (`main/boards/common/board.h`):
- `WifiBoard` - Wi-Fi connected boards
- `Ml307Board` - 4G (ML307 Cat.1) boards
- `DualNetworkBoard` - Wi-Fi + 4G switchable boards

Each board directory (`main/boards/<board-name>/`) contains:
- `config.h` - Hardware pin mappings and configurations
- `config.json` - Build configuration (target chip, flash size, partition table)
- `<board_name>.cc` - Board initialization and component setup
- `README.md` - Board-specific documentation

### Key Components
- **Application** (`main/application.cc`) - Main event loop, state machine, orchestrates all components
- **Protocol** (`main/protocols/`) - WebSocket or MQTT+UDP communication with backend
- **Audio Service** (`main/audio/`) - Audio codec abstraction, wake word detection, OPUS encoding
- **Display** (`main/display/`) - OLED, LCD, LVGL display drivers
- **MCP Server** (`main/mcp_server.cc`) - JSON-RPC 2.0 server for device control tools
- **Assets** (`main/assets/`) - Multilingual audio prompts, fonts, emoji collections

### Device State Machine
States: `kDeviceStateStarting` → `kDeviceStateConnecting` → `kDeviceStateIdle` → `kDeviceStateListening` → `kDeviceStateSpeaking` → `kDeviceStateUpgrading`

### MCP Protocol Flow
1. Device sends "hello" with capabilities (including `"mcp": true`)
2. Backend sends `initialize` request
3. Backend discovers tools via `tools/list`
4. Backend invokes tools via `tools/call`
5. Device responds with JSON-RPC 2.0 formatted results

See `docs/mcp-protocol.md` for complete protocol documentation.

## Adding Custom Boards

**Critical Warning**: Never overwrite an existing board's configuration. Always create a new board directory to ensure OTA upgrades don't replace custom firmware.

1. Create directory: `main/boards/<manufacturer>-<board-name>/`
2. Add files: `config.h`, `config.json`, `<board_name>.cc`, `README.md`
3. Inherit from appropriate base class (`WifiBoard`, `Ml307Board`, etc.)
4. Implement virtual methods: `GetAudioCodec()`, `GetDisplay()`, `GetNetwork()`, etc.
5. Register board with `DECLARE_BOARD(ClassName)` macro
6. Add config to `main/Kconfig.projbuild` (choice BOARD_TYPE section)
7. Add cmake condition in `main/CMakeLists.txt`
8. Test with: `python scripts/release.py <board-directory-name>`

See `docs/custom-board.md` for detailed guide.

## Code Style

- Google C++ style with project-specific overrides (see `.clang-format`)
- 4-space indentation, 100-character line limit
- Use `// clang-format off` / `on` to exclude sections from formatting
- Format all code before committing

## Configuration Files

- `sdkconfig.defaults` - Base ESP-IDF configuration
- `sdkconfig.defaults.<chip>` - Chip-specific overrides (esp32s3, esp32c3, etc.)
- `main/Kconfig.projbuild` - Project configuration options (board selection, features)
- `partitions/v2/*.csv` - Partition tables for different flash sizes

## Common Development Tasks

### Adding MCP Tools
In board initialization or `main/mcp_server.cc`:
```cpp
McpServer::GetInstance().AddTool(
    "tool.name",
    "Tool description",
    PropertyList{
        Property("param1", kPropertyTypeString),
        Property("param2", kPropertyTypeInteger, 0, 100)  // min, max
    },
    [](const PropertyList& props) -> ReturnValue {
        // Tool implementation
        return true;  // or string, int, cJSON*, ImageContent*
    }
);
```

### Adding Audio Codecs
Create codec class inheriting from `AudioCodec` in `main/audio/codecs/`. Implement `Open()`, `Close()`, `Read()`, `Write()` methods.

### Adding Display Drivers
For simple displays: Use `OledDisplay` or `LcdDisplay` abstractions
For complex UIs: Use LVGL in `main/display/lvgl_display/`

## Important Documentation

- `docs/custom-board.md` - Creating custom boards
- `docs/mcp-protocol.md` - MCP protocol specification
- `docs/mcp-usage.md` - Using MCP for IoT control
- `docs/websocket.md` - WebSocket protocol details
- `docs/mqtt-udp.md` - MQTT+UDP hybrid protocol
- `docs/code_style.md` - Code formatting guidelines

## Troubleshooting

- Display issues: Check SPI configuration, mirror/swap settings in `config.h`
- Audio issues: Verify I2S pins, I2C codec address, PA enable pin
- Network issues: Check Wi-Fi credentials, verify board inherits correct network class
- Build failures: Run `idf.py fullclean`, verify target chip matches hardware
