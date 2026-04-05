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

    @Published var firmwarePath: String = ""
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
    private let processRunner = ProcessRunner()
    private let serialPortService = SerialPortService()
    private var activeFlashProcess: Process?
    private var isFlashing = false
    private var allPorts: [SerialPortInfo] = []
    private var extractedFirmwareDirectoryURL: URL?

    init() {
        refreshPorts()
        checkEnvironment()
    }

    deinit {
        serialPortService.close()
        if let dir = extractedFirmwareDirectoryURL {
            try? FileManager.default.removeItem(at: dir)
        }
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
            && !firmwarePath.isEmpty
            && FileManager.default.fileExists(atPath: firmwarePath)
            && isSupportedFirmwarePath(firmwarePath)
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

    func selectFirmwareFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "bin"),
            UTType(filenameExtension: "zip"),
        ].compactMap { $0 }

        if panel.runModal() == .OK {
            firmwarePath = panel.url?.path ?? ""
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
            flashState = .failed("环境检查失败，请检查 python3 与内置 esptool 资源。")
            return
        }
        guard !firmwarePath.isEmpty, FileManager.default.fileExists(atPath: firmwarePath) else {
            flashState = .failed("请选择有效的 .bin 或 .zip 固件文件。")
            return
        }
        guard isSupportedFirmwarePath(firmwarePath) else {
            flashState = .failed("仅支持 .bin 或 .zip 固件文件。")
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

        let sourceFirmwarePath = firmwarePath
        let binPathForFlash: String
        do {
            binPathForFlash = try resolveBinPathForFlash(from: sourceFirmwarePath)
        } catch {
            isFlashing = false
            flashState = .failed(error.localizedDescription)
            appendFlashLog("[错误] \(error.localizedDescription)\n")
            return
        }

        appendFlashLog("[信息] 固件源: \(sourceFirmwarePath)\n")
        if sourceFirmwarePath != binPathForFlash {
            appendFlashLog("[信息] 使用解压后的固件: \(binPathForFlash)\n")
        }
        appendFlashLog("[信息] 串口: \(flashPortPath), 波特率: \(baudRate)\n")
        appendFlashLog("[命令] \(esptoolService.flashCommandDescription(binPath: binPathForFlash, port: flashPortPath, baudRate: baudRate))\n\n")

        do {
            activeFlashProcess = try esptoolService.flashBin(
                binPath: binPathForFlash,
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
                        self.cleanupExtractedFirmwareDirectory()
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
            cleanupExtractedFirmwareDirectory()
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
            flashState = .failed("环境检查失败，请检查 python3 与内置 esptool 资源。")
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
        appendFlashLog("[命令] \(esptoolService.eraseCommandDescription(port: flashPortPath))\n\n")

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

    private func isSupportedFirmwarePath(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ext == "bin" || ext == "zip"
    }

    private func resolveBinPathForFlash(from sourcePath: String) throws -> String {
        let ext = URL(fileURLWithPath: sourcePath).pathExtension.lowercased()
        switch ext {
        case "bin":
            return sourcePath
        case "zip":
            appendFlashLog("[信息] 检测到 ZIP 固件，正在解压...\n")
            cleanupExtractedFirmwareDirectory()

            let extractedDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("flashgui-firmware-\(UUID().uuidString)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
            } catch {
                throw NSError(
                    domain: "FlashGUI",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "创建临时解压目录失败：\(error.localizedDescription)"]
                )
            }

            let unzipResult = processRunner.runSync(command: ["unzip", "-o", sourcePath, "-d", extractedDir.path])
            guard unzipResult.exitCode == 0 else {
                try? FileManager.default.removeItem(at: extractedDir)
                let detailRaw = [unzipResult.stderr, unzipResult.stdout]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first(where: { !$0.isEmpty }) ?? ""
                let detail = detailRaw.replacingOccurrences(of: "\n", with: " ")
                let message = detail.isEmpty ? "解压 ZIP 固件失败。" : "解压 ZIP 固件失败：\(detail)"
                throw NSError(
                    domain: "FlashGUI",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }

            guard let extractedBinPath = findFirmwareBinPath(in: extractedDir) else {
                try? FileManager.default.removeItem(at: extractedDir)
                throw NSError(
                    domain: "FlashGUI",
                    code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "ZIP 中未找到 .bin 固件文件。"]
                )
            }

            extractedFirmwareDirectoryURL = extractedDir
            appendFlashLog("[信息] ZIP 解压目录: \(extractedDir.path)\n")
            return extractedBinPath
        default:
            throw NSError(
                domain: "FlashGUI",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "仅支持 .bin 或 .zip 固件文件。"]
            )
        }
    }

    private func findFirmwareBinPath(in directory: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var binCandidates: [String] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "bin" else {
                continue
            }
            binCandidates.append(fileURL.path)
        }

        guard !binCandidates.isEmpty else {
            return nil
        }

        if let mergedBin = binCandidates.first(where: {
            URL(fileURLWithPath: $0).lastPathComponent.lowercased() == "merged-binary.bin"
        }) {
            return mergedBin
        }
        return binCandidates.sorted().first
    }

    private func cleanupExtractedFirmwareDirectory() {
        guard let dir = extractedFirmwareDirectoryURL else {
            return
        }
        try? FileManager.default.removeItem(at: dir)
        extractedFirmwareDirectoryURL = nil
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
