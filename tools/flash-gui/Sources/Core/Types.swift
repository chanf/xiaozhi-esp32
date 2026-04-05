import Foundation

enum OperationState: Equatable {
    case idle
    case running
    case success
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            return "空闲"
        case .running:
            return "运行中"
        case .success:
            return "成功"
        case .failed:
            return "失败"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "当前没有任务在运行。"
        case .running:
            return "任务运行中..."
        case .success:
            return "任务已完成。"
        case .failed(let error):
            return error
        }
    }
}

struct SerialPortInfo: Identifiable, Hashable {
    let path: String
    let name: String

    var id: String { path }

    var displayName: String {
        if name.isEmpty {
            return path
        }
        return "\(name) (\(path))"
    }
}

struct EnvironmentStatus {
    let isReady: Bool
    let summary: String
    let detail: String
    let installHint: String

    static let checking = EnvironmentStatus(
        isReady: false,
        summary: "正在检查 python3 和 esptool...",
        detail: "",
        installHint: "python3 -m pip install --upgrade esptool"
    )
}
