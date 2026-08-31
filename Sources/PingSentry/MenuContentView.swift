import SwiftUI

struct MenuContentView: View {
    @ObservedObject var monitor: PingMonitor
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monitor.host).font(.headline)
            if let latency = monitor.lastLatencyMs, !monitor.lastFailed {
                Text("Ultimo ping: \(String(format: "%.1f", latency)) ms")
            } else {
                Text("Ultimo ping: timeout")
                    .foregroundStyle(.red)
            }
            Text("Pacchetti persi: \(String(format: "%.0f", monitor.lossPercent))% (ultimi \(monitor.windowSize))")
                .foregroundStyle(.secondary)

            Divider()

            Button("Pinga ora") {
                monitor.pingNow()
            }

            Button("Impostazioni…") {
                openSettings()
            }
            .keyboardShortcut(",")

            Button("Info su PingSentry") {
                openWindow(id: "about")
            }

            Divider()

            Button("Esci") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
