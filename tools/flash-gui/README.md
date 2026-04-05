# flash-gui (macOS)

Native macOS GUI flasher and serial monitor for ESP32 devices, built with SwiftUI and SwiftPM.

## Features

- Flash `merged-binary.bin` to ESP32-S3 (`0x0`) with one click
- Erase flash with one click
- Serial monitor with:
  - port and baud selection
  - start/stop
  - send one command line (`\n` appended automatically)
  - clear log
  - save log to file
- Environment precheck at startup:
  - `python3`
  - `python3 -m esptool version`

If `esptool` is missing, install it manually:

```bash
python3 -m pip install --upgrade esptool
```

## Build and Run (CLI only)

```bash
cd tools/flash-gui
swift build
swift run
```

Release build:

```bash
swift build -c release
```

## Flash Command Used

Flash:

```bash
python3 -m esptool --chip esp32s3 --port <PORT> --baud <BAUD> write_flash -z 0x0 <BIN_PATH>
```

Erase:

```bash
python3 -m esptool --chip esp32s3 --port <PORT> erase_flash
```

## Notes

- The GUI disables flashing while serial monitor is running.
- The GUI does not auto-install Python dependencies.
- V1 supports direct `.bin` flashing only (no ZIP auto-extract, no multi-partition layout).
- If flashing fails at high speed, retry with a lower baud rate such as `460800` or `115200`.
