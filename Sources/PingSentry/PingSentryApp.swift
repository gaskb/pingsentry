import SwiftUI

@main
struct PingSentryApp: App {
    @StateObject private var monitor: PingMonitor
    @AppStorage("host") private var host: String = "1.1.1.1"
    @AppStorage("intervalSeconds") private var intervalSeconds: Double = 2.0
    @AppStorage("windowSize") private var windowSize: Int = 20

    init() {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: "host") ?? "1.1.1.1"
        let interval = defaults.object(forKey: "intervalSeconds") as? Double ?? 2.0
        let window = defaults.object(forKey: "windowSize") as? Int ?? 20
        _monitor = StateObject(wrappedValue: PingMonitor(host: host, intervalSeconds: interval, windowSize: window))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(monitor: monitor, host: $host, intervalSeconds: $intervalSeconds, windowSize: $windowSize)
        } label: {
            MenuBarLabel(monitor: monitor)
                .task { monitor.start() }
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var monitor: PingMonitor

    var body: some View {
        let quality = monitor.quality
        let isAlert = quality == .none
        let icon = StatusIconRenderer.makeIcon(filledBars: quality.bars, isAlert: isAlert)

        HStack(spacing: 4) {
            Image(nsImage: icon)
            Text(labelText)
                .font(.system(size: 12, design: .monospaced))
        }
    }

    private var labelText: String {
        let ms: String
        if let latency = monitor.lastLatencyMs, !monitor.lastFailed {
            ms = "\(Int(latency.rounded()))ms"
        } else {
            ms = "—"
        }
        let loss = Int(monitor.lossPercent.rounded())
        return "\(ms) (\(loss)%)"
    }
}
