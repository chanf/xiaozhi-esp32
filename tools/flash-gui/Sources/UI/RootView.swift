import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            FlashView()
                .tabItem {
                    Label("烧录工具", systemImage: "bolt.fill")
                }

            SerialMonitorView()
                .tabItem {
                    Label("串口监视", systemImage: "terminal")
                }
        }
        .padding(12)
    }
}
