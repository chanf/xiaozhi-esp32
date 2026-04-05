import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var ports: [SerialPortInfo] = []
    @Published var showFlashablePortsOnly: Bool = true {
        didSet {
            applyPortFilterAndSyncSelection()
        }
    }

    @Published var environmentStatus: EnvironmentStatus = .checking

    @Published var binPath: String = ""
    @Published var flashPortPath: String = ""
    @Published var flashBaudRate: String = "921600"
    @Published var flashState: OperationState = .idle
    @Published var flashLog: String = ""

    @Published var monitorPortPath: String = ""
    @Published var monitorBaudRate: String = "115200"
    @Published var monitorState: OperationState = .idle
    @Published var monitorLog: String = ""
    @Published var monitorInput: String = ""

    let commonBaudRates: [Int] = [115200, 230400, 460800, 921600]

    private let esptoolService = EsptoolService()
    private let serialPortService = SerialPortService()
    private var activeFlashProcess: Process?
    private var isFlashing = false
    private var allPorts: [SerialPortInfo] = []

    init() {
        refreshPorts()
        checkEnvironment()
    }

    deinit {
        serialPortService.close()
    }

    var monitorRunning: Bool {
        monitorState == .running
    }

    var canStartMonitor: Bool {
        !monitorRunning && !isFlashing && !monitorPortPath.isEmpty && Int(monitorBaudRate) != nil
    }

    var canRunFlash: Bool {
        !isFlashing
            && !monitorRunning
            && environmentStatus.isReady
            && !flashPortPath.isEmpty
            && !binPath.isEmpty
            && FileManager.default.fileExists(atPath: binPath)
            && Int(flashBaudRate) != nil
    }

    var canRunErase: Bool {
        !isFlashing
            && !monitorRunning
            && environmentStatus.isReady
            && !flashPortPath.isEmpty
    }

    func refreshPorts() {
        let updated = serialPortService.listPorts()
        allPorts = updated
        applyPortFilterAndSyncSelection()
    }

    func checkEnvironment() {
        environmentStatus = .checking
        environmentStatus = esptoolService.checkEnvironment()
    }

    func selectBinFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "bin")].compactMap { $0 }

        if panel.runModal() == .OK {
            binPath = panel.url?.path ?? ""
        }
    }

    func clearFlashLog() {
        flashLog = ""
    }

    func flashBin() {
        guard !monitorRunning else {
            flashState = .failed("请先停止串口监视器，再执行烧录。")
            return
        }
        guard environmentStatus.isReady else {
            flashState = .failed("环境检查失败，请先安装 esptool。")
            return
        }
        guard !binPath.isEmpty, FileManager.default.fileExists(atPath: binPath) else {
            flashState = .failed("请选择有效的 .bin 固件文件。")
            return
        }
        guard !flashPortPath.isEmpty else {
            flashState = .failed("请选择串口。")
            return
        }
        guard !isLikelyBluetoothPort(flashPortPath) else {
            flashState = .failed("当前是蓝牙串口（\(flashPortPath)），请切换到开发板 USB 串口（通常是 /dev/cu.usb*）。")
            return
        }
        guard let baudRate = Int(flashBaudRate) else {
            flashState = .failed("烧录波特率无效。")
            return
        }
        guard !isFlashing else {
            return
        }

        flashState = .running
        flashLog = ""
        isFlashing = true
        appendFlashLog("[信息] 正在烧录 \(binPath)\n")
        appendFlashLog("[信息] 串口: \(flashPortPath), 波特率: \(baudRate)\n")
        appendFlashLog("[命令] python3 -m esptool --chip esp32s3 --port \(flashPortPath) --baud \(baudRate) write-flash -z 0x0 \(binPath)\n\n")

        do {
            activeFlashProcess = try esptoolService.flashBin(
                binPath: binPath,
                port: flashPortPath,
                baudRate: baudRate,
                onOutput: { [weak self] text in
                    Task { @MainActor in
                        self?.appendFlashLog(text)
                    }
                },
                onCompletion: { [weak self] exitCode in
                    Task { @MainActor in
                        guard let self else { return }
                        self.isFlashing = false
                        self.activeFlashProcess = nil
                        if exitCode == 0 {
                            self.flashState = .success
                            self.appendFlashLog("\n[信息] 烧录完成。\n")
                        } else {
                            self.flashState = .failed("烧录失败，退出码 \(exitCode)。")
                            self.appendFlashLog("\n[错误] 烧录失败，退出码 \(exitCode)。\n")
                        }
                    }
                }
            )
        } catch {
            isFlashing = false
            activeFlashProcess = nil
            flashState = .failed(error.localizedDescription)
            appendFlashLog("[错误] \(error.localizedDescription)\n")
        }
    }

    func eraseFlash() {
        guard !monitorRunning else {
            flashState = .failed("请先停止串口监视器，再执行擦除。")
            return
        }
        guard environmentStatus.isReady else {
            flashState = .failed("环境检查失败，请先安装 esptool。")
            return
        }
        guard !flashPortPath.isEmpty else {
            flashState = .failed("请选择串口。")
            return
        }
        guard !isLikelyBluetoothPort(flashPortPath) else {
            flashState = .failed("当前是蓝牙串口（\(flashPortPath)），请切换到开发板 USB 串口（通常是 /dev/cu.usb*）。")
            return
        }
        guard !isFlashing else {
            return
        }

        flashState = .running
        flashLog = ""
        isFlashing = true
        appendFlashLog("[信息] 正在擦除 \(flashPortPath) 的 Flash\n")
        appendFlashLog("[命令] python3 -m esptool --chip esp32s3 --port \(flashPortPath) erase-flash\n\n")

        do {
            activeFlashProcess = try esptoolService.eraseFlash(
                port: flashPortPath,
                onOutput: { [weak self] text in
                    Task { @MainActor in
                        self?.appendFlashLog(text)
                    }
                },
                onCompletion: { [weak self] exitCode in
                    Task { @MainActor in
                        guard let self else { return }
                        self.isFlashing = false
                        self.activeFlashProcess = nil
                        if exitCode == 0 {
                            self.flashState = .success
                            self.appendFlashLog("\n[信息] 擦除完成。\n")
                        } else {
                            self.flashState = .failed("擦除失败，退出码 \(exitCode)。")
                            self.appendFlashLog("\n[错误] 擦除失败，退出码 \(exitCode)。\n")
                        }
                    }
                }
            )
        } catch {
            isFlashing = false
            activeFlashProcess = nil
            flashState = .failed(error.localizedDescription)
            appendFlashLog("[错误] \(error.localizedDescription)\n")
        }
    }

    func startMonitor() {
        guard !isFlashing else {
            monitorState = .failed("烧录任务正在运行，请稍后再试。")
            return
        }
        guard !monitorRunning else {
            return
        }
        guard !monitorPortPath.isEmpty else {
            monitorState = .failed("请选择串口。")
            return
        }
        guard let baudRate = Int(monitorBaudRate) else {
            monitorState = .failed("监视波特率无效。")
            return
        }

        monitorState = .running
        monitorLog = ""
        appendMonitorLog("[信息] 开始监视：\(monitorPortPath), 波特率 \(baudRate)\n")

        let opened = serialPortService.open(
            path: monitorPortPath,
            baudRate: baudRate,
            onData: { [weak self] text in
                Task { @MainActor in
                    self?.appendMonitorLog(text)
                }
            },
            onDisconnect: { [weak self] message in
                Task { @MainActor in
                    guard let self else { return }
                    self.appendMonitorLog("\n[警告] \(message)\n")
                    self.monitorState = .failed(message)
                }
            },
            onError: { [weak self] message in
                Task { @MainActor in
                    self?.appendMonitorLog("\n[错误] \(message)\n")
                }
            }
        )

        if !opened {
            monitorState = .failed("打开串口监视器失败。")
        }
    }

    func stopMonitor() {
        serialPortService.close()
        if monitorState == .running {
            monitorState = .idle
            appendMonitorLog("\n[信息] 串口监视器已停止。\n")
        }
    }

    func sendMonitorLine() {
        let line = monitorInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        guard monitorRunning else {
            appendMonitorLog("[警告] 串口监视器未运行。\n")
            return
        }

        let ok = serialPortService.sendLine(line)
        if ok {
            appendMonitorLog("\n> \(line)\n")
            monitorInput = ""
        } else {
            appendMonitorLog("[错误] 发送失败。\n")
        }
    }

    func clearMonitorLog() {
        monitorLog = ""
    }

    func saveMonitorLog() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "串口监视.log"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try monitorLog.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            appendMonitorLog("[错误] 保存日志失败：\(error.localizedDescription)\n")
        }
    }

    private func appendFlashLog(_ text: String) {
        flashLog.append(text)
    }

    private func appendMonitorLog(_ text: String) {
        monitorLog.append(text)
    }

    private func applyPortFilterAndSyncSelection() {
        let filtered = showFlashablePortsOnly
            ? allPorts.filter { isLikelyHardwareSerial($0.path) }
            : allPorts

        ports = filtered

        let preferredPath = preferredPortPath(in: filtered)
        if !filtered.contains(where: { $0.path == flashPortPath }) {
            flashPortPath = preferredPath ?? filtered.first?.path ?? ""
        }
        if !filtered.contains(where: { $0.path == monitorPortPath }) {
            monitorPortPath = preferredPath ?? filtered.first?.path ?? ""
        }
    }

    private func preferredPortPath(in list: [SerialPortInfo]) -> String? {
        let preferred = list.first(where: { isLikelyHardwareSerial($0.path) })
        return preferred?.path
    }

    private func isLikelyHardwareSerial(_ path: String) -> Bool {
        let lower = path.lowercased()
        if lower.contains("bluetooth") {
            return false
        }
        return lower.contains("usb")
            || lower.contains("serial")
            || lower.contains("wch")
            || lower.contains("slab")
            || lower.contains("cp210")
            || lower.contains("ch34")
    }

    private func isLikelyBluetoothPort(_ path: String) -> Bool {
        path.lowercased().contains("bluetooth")
    }
}
