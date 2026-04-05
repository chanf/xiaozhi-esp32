import Foundation

final class EsptoolService {
    private let processRunner = ProcessRunner()

    func checkEnvironment() -> EnvironmentStatus {
        let pythonResult = processRunner.runSync(command: ["python3", "--version"])
        if pythonResult.exitCode != 0 {
            return EnvironmentStatus(
                isReady: false,
                summary: "未检测到 python3。",
                detail: pythonResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                installHint: "请先安装 Python 3，然后执行：python3 -m pip install --upgrade esptool"
            )
        }

        let esptoolResult = processRunner.runSync(command: ["python3", "-m", "esptool", "version"])
        if esptoolResult.exitCode != 0 {
            let detail = """
            \(pythonResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
            \(esptoolResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            """.trimmingCharacters(in: .whitespacesAndNewlines)

            return EnvironmentStatus(
                isReady: false,
                summary: "当前 python3 环境未安装 esptool。",
                detail: detail,
                installHint: "python3 -m pip install --upgrade esptool"
            )
        }

        let detail = """
        \(pythonResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        \(esptoolResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        return EnvironmentStatus(
            isReady: true,
            summary: "环境检查通过。",
            detail: detail,
            installHint: "python3 -m pip install --upgrade esptool"
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
        let command = [
            "python3", "-m", "esptool",
            "--chip", chip,
            "--port", port,
            "--baud", "\(baudRate)",
            "write-flash",
            "-z",
            address,
            binPath,
        ]
        return try processRunner.runAsync(command: command, onOutput: onOutput, onCompletion: onCompletion)
    }

    @discardableResult
    func eraseFlash(
        port: String,
        chip: String = "esp32s3",
        onOutput: @escaping (String) -> Void,
        onCompletion: @escaping (Int32) -> Void
    ) throws -> Process {
        let command = [
            "python3", "-m", "esptool",
            "--chip", chip,
            "--port", port,
            "erase-flash",
        ]
        return try processRunner.runAsync(command: command, onOutput: onOutput, onCompletion: onCompletion)
    }
}
