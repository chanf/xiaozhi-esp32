import Foundation

final class EsptoolService {
    private let processRunner = ProcessRunner()
    private let fileManager = FileManager.default
    private let vendorRelativePath = "vendor/python"

    func flashCommandDescription(
        binPath: String,
        port: String,
        baudRate: Int,
        chip: String = "esp32s3",
        address: String = "0x0"
    ) -> String {
        let command = buildFlashCommand(
            binPath: binPath,
            port: port,
            baudRate: baudRate,
            chip: chip,
            address: address
        ).joined(separator: " ")
        if let vendorPath = resolveBundledPythonVendorPath() {
            return "\(command)\n[信息] 使用内置 esptool：\(vendorPath)"
        }
        return "\(command)\n[警告] 未找到内置 esptool 资源。"
    }

    func eraseCommandDescription(
        port: String,
        chip: String = "esp32s3"
    ) -> String {
        let command = buildEraseCommand(port: port, chip: chip).joined(separator: " ")
        if let vendorPath = resolveBundledPythonVendorPath() {
            return "\(command)\n[信息] 使用内置 esptool：\(vendorPath)"
        }
        return "\(command)\n[警告] 未找到内置 esptool 资源。"
    }

    func checkEnvironment() -> EnvironmentStatus {
        let pythonResult = processRunner.runSync(command: ["python3", "--version"])
        if pythonResult.exitCode != 0 {
            return EnvironmentStatus(
                isReady: false,
                summary: "未检测到 python3。",
                detail: pythonResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                installHint: "请先安装 Python 3。"
            )
        }

        guard let vendorPath = resolveBundledPythonVendorPath() else {
            return EnvironmentStatus(
                isReady: false,
                summary: "未找到内置 esptool 资源。",
                detail: "请确认应用目录下存在 \(vendorRelativePath)/esptool。",
                installHint: "请重新构建或重新打包应用。"
            )
        }

        let esptoolResult = processRunner.runSync(
            command: ["python3", "-m", "esptool", "version"],
            environment: makePythonEnvironment(vendorPath: vendorPath)
        )
        if esptoolResult.exitCode != 0 {
            let detail = """
            \(pythonResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
            \(esptoolResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
            \(esptoolResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            内置 esptool 路径：\(vendorPath)
            """.trimmingCharacters(in: .whitespacesAndNewlines)

            return EnvironmentStatus(
                isReady: false,
                summary: "内置 esptool 启动失败。",
                detail: detail,
                installHint: "请检查内置依赖是否完整，或重新打包应用。"
            )
        }

        let detail = """
        \(pythonResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        \(esptoolResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        内置 esptool 路径：\(vendorPath)
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        return EnvironmentStatus(
            isReady: true,
            summary: "环境检查通过。",
            detail: detail,
            installHint: "请先安装 Python 3。"
        )
    }

    @discardableResult
    func flashBin(
        binPath: String,
        port: String,
        baudRate: Int,
        chip: String = "esp32s3",
        address: String = "0x0",
        onOutput: @escaping (String) -> Void,
        onCompletion: @escaping (Int32) -> Void
    ) throws -> Process {
        guard let vendorPath = resolveBundledPythonVendorPath() else {
            throw ProcessRunnerError.launchFailed("未找到内置 esptool 资源，请重新构建或重新打包应用。")
        }

        return try processRunner.runAsync(
            command: buildFlashCommand(
                binPath: binPath,
                port: port,
                baudRate: baudRate,
                chip: chip,
                address: address
            ),
            environment: makePythonEnvironment(vendorPath: vendorPath),
            onOutput: onOutput,
            onCompletion: onCompletion
        )
    }

    @discardableResult
    func eraseFlash(
        port: String,
        chip: String = "esp32s3",
        onOutput: @escaping (String) -> Void,
        onCompletion: @escaping (Int32) -> Void
    ) throws -> Process {
        guard let vendorPath = resolveBundledPythonVendorPath() else {
            throw ProcessRunnerError.launchFailed("未找到内置 esptool 资源，请重新构建或重新打包应用。")
        }

        return try processRunner.runAsync(
            command: buildEraseCommand(port: port, chip: chip),
            environment: makePythonEnvironment(vendorPath: vendorPath),
            onOutput: onOutput,
            onCompletion: onCompletion
        )
    }

    private func buildFlashCommand(
        binPath: String,
        port: String,
        baudRate: Int,
        chip: String,
        address: String
    ) -> [String] {
        [
            "python3", "-m", "esptool",
            "--chip", chip,
            "--port", port,
            "--baud", "\(baudRate)",
            "write_flash",
            "-z",
            address,
            binPath,
        ]
    }

    private func buildEraseCommand(port: String, chip: String) -> [String] {
        [
            "python3", "-m", "esptool",
            "--chip", chip,
            "--port", port,
            "erase_flash",
        ]
    }

    private func makePythonEnvironment(vendorPath: String) -> [String: String] {
        let existingPythonPath = ProcessInfo.processInfo.environment["PYTHONPATH"] ?? ""
        let pythonPath: String
        if existingPythonPath.isEmpty {
            pythonPath = vendorPath
        } else {
            pythonPath = "\(vendorPath):\(existingPythonPath)"
        }
        return [
            "PYTHONPATH": pythonPath,
            "PYTHONNOUSERSITE": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
        ]
    }

    private func resolveBundledPythonVendorPath() -> String? {
        for path in candidateVendorPaths() {
            let esptoolInit = URL(fileURLWithPath: path, isDirectory: true)
                .appendingPathComponent("esptool/__init__.py")
                .path
            if fileManager.fileExists(atPath: esptoolInit) {
                return path
            }
        }
        return nil
    }

    private func candidateVendorPaths() -> [String] {
        var results: [String] = []
        var seen: Set<String> = []

        func append(_ url: URL?) {
            guard let url else { return }
            let standardized = url.standardizedFileURL.path
            guard !seen.contains(standardized) else { return }
            seen.insert(standardized)
            results.append(standardized)
        }

        if let resourceURL = Bundle.main.resourceURL {
            append(resourceURL.appendingPathComponent(vendorRelativePath, isDirectory: true))
        }

        append(URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(vendorRelativePath, isDirectory: true))

        if let executablePath = CommandLine.arguments.first, executablePath.contains("/") {
            let executableURL = URL(fileURLWithPath: executablePath).standardizedFileURL
            append(executableURL.deletingLastPathComponent()
                .appendingPathComponent(vendorRelativePath, isDirectory: true))
        }

        if let executableURL = Bundle.main.executableURL {
            var cursor = executableURL.deletingLastPathComponent()
            for _ in 0..<8 {
                append(cursor.appendingPathComponent(vendorRelativePath, isDirectory: true))
                cursor.deleteLastPathComponent()
            }
        }

        return results
    }
}
