import SwiftUI

struct SerialMonitorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("监视器设置") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("串口")
                        Picker("串口", selection: $model.monitorPortPath) {
                            if model.ports.isEmpty {
                                Text("无可用串口").tag("")
                            }
                            ForEach(model.ports) { port in
                                Text(port.displayName).tag(port.path)
                            }
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("波特率")
                        Picker("波特率", selection: $model.monitorBaudRate) {
                            ForEach(model.commonBaudRates.map(String.init), id: \.self) { baud in
                                Text(baud).tag(baud)
                            }
                        }
                        .labelsHidden()
                    }

                    Spacer()

                    Button("刷新串口") {
                        model.refreshPorts()
                    }
                }

                Toggle("仅显示可烧录串口（隐藏蓝牙）", isOn: $model.showFlashablePortsOnly)
                    .toggleStyle(.switch)

                if model.ports.isEmpty {
                    Text(model.showFlashablePortsOnly ? "未发现可烧录串口，请连接开发板后刷新。" : "未发现串口，请连接开发板后刷新。")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }

            if model.flashState == .running {
                Text("烧录任务正在运行，暂时不能启动串口监视器。")
                    .foregroundColor(.orange)
            }

            HStack(spacing: 10) {
                if model.monitorRunning {
                    Button("停止监视") {
                        model.stopMonitor()
                    }
                } else {
                    Button("启动监视") {
                        model.startMonitor()
                    }
                    .disabled(!model.canStartMonitor)
                }

                Button("清空日志") {
                    model.clearMonitorLog()
                }

                Button("保存日志") {
                    model.saveMonitorLog()
                }
            }

            HStack {
                Text("状态：\(model.monitorState.title)")
                    .bold()
                Text(model.monitorState.message)
                    .foregroundColor(.secondary)
                Spacer()
            }

            GroupBox("串口日志") {
                TextEditor(text: $model.monitorLog)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(minHeight: 320)
            }

            HStack {
                TextField("输入一行命令并发送", text: $model.monitorInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!model.monitorRunning)
                Button("发送") {
                    model.sendMonitorLine()
                }
                .disabled(!model.monitorRunning)
            }
        }
    }
}
