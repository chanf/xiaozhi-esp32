import Foundation

enum ProcessRunnerError: LocalizedError {
    case emptyCommand
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyCommand:
            return "命令为空。"
        case .launchFailed(let reason):
            return "启动进程失败：\(reason)"
        }
    }
}

struct SyncProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

final class ProcessRunner {
    func runSync(command: [String]) -> SyncProcessResult {
        guard !command.isEmpty else {
            return SyncProcessResult(exitCode: -1, stdout: "", stderr: ProcessRunnerError.emptyCommand.localizedDescription)
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return SyncProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return SyncProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }

    @discardableResult
    func runAsync(
        command: [String],
        onOutput: @escaping (String) -> Void,
        onCompletion: @escaping (Int32) -> Void
    ) throws -> Process {
        guard !command.isEmpty else {
            throw ProcessRunnerError.emptyCommand
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let outputHandler: (FileHandle) -> Void = { fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty {
                return
            }

            let text = String(decoding: data, as: UTF8.self)
            onOutput(text)
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = outputHandler
        stderrPipe.fileHandleForReading.readabilityHandler = outputHandler

        process.terminationHandler = { process in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            onCompletion(process.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        return process
    }
}
