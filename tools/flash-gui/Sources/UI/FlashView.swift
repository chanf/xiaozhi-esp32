import SwiftUI

struct FlashView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("环境检查") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.environmentStatus.summary)
                        .foregroundColor(model.environmentStatus.isReady ? .green : .orange)
                    if !model.environmentStatus.detail.isEmpty {
                        Text(model.environmentStatus.detail)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if !model.environmentStatus.isReady {
                        Text("提示：\(model.environmentStatus.installHint)")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                    }
                    HStack {
                        Spacer()
                        Button("重新检查") {
                            model.checkEnvironment()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("固件") {
                HStack {
                    TextField("选择 .bin 或 .zip 固件文件路径", text: $model.firmwarePath)
                        .textFieldStyle(.roundedBorder)
                    Button("浏览...") {
                        model.selectFirmwareFile()
                    }
                }
            }

            GroupBox("烧录设置") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("串口")
                        Picker("串口", selection: $model.flashPortPath) {
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
                        Picker("波特率", selection: $model.flashBaudRate) {
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

            if model.monitorRunning {
                Text("串口监视器正在运行，请先停止再烧录。")
                    .foregroundColor(.orange)
            }

            HStack(spacing: 10) {
                Button("烧录固件") {
                    model.flashBin()
                }
                .disabled(!model.canRunFlash)

                Button("擦除 Flash") {
                    model.eraseFlash()
                }
                .disabled(!model.canRunErase)

                Button("清空日志") {
                    model.clearFlashLog()
                }
            }

            HStack {
                Text("状态：\(model.flashState.title)")
                    .bold()
                Text(model.flashState.message)
                    .foregroundColor(.secondary)
                Spacer()
            }

            GroupBox("烧录日志") {
                AutoScrollingFlashLogView(text: model.flashLog)
                    .frame(minHeight: 320)
            }
        }
    }
}

private struct AutoScrollingFlashLogView: View {
    private enum Anchor {
        static let bottom = "flash-log-bottom"
    }

    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(text.isEmpty ? "暂无日志输出。" : text)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)

                    Color.clear
                        .frame(height: 1)
                        .id(Anchor.bottom)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: text) { _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            proxy.scrollTo(Anchor.bottom, anchor: .bottom)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.12), action)
        } else {
            action()
        }
    }
}
