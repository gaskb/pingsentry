import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var monitor: PingMonitor?

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }
}

@main
struct PingSentryApp: App {
    @StateObject private var monitor: PingMonitor
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: "host") ?? "1.1.1.1"
        let interval = defaults.object(forKey: "intervalSeconds") as? Double ?? 2.0
        let window = defaults.object(forKey: "windowSize") as? Int ?? 20
        let notify = defaults.object(forKey: "notifyOnStateChange") as? Bool ?? true

        let created = PingMonitor(host: host, intervalSeconds: interval, windowSize: window)
        created.notifyOnStateChange = notify
        _monitor = StateObject(wrappedValue: created)
        appDelegate.monitor = created
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
                .task { monitor.start() }
        }
        .menuBarExtraStyle(.menu)

        Window("Info su PingSentry", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Window("Statistiche", id: "stats") {
            StatsView(monitor: monitor)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(monitor: monitor)
        }
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var monitor: PingMonitor
    @AppStorage("showLatency") private var showLatency: Bool = true
    @AppStorage("showLossPercent") private var showLossPercent: Bool = true
    @AppStorage("showBarsIcon") private var showBarsIcon: Bool = true

    var body: some View {
        let quality = monitor.quality
        let isAlert = quality == .none
        let icon = StatusIconRenderer.makeIcon(filledBars: quality.bars, isAlert: isAlert)
        let hasText = showLatency || showLossPercent

        HStack(spacing: 4) {
            if showBarsIcon || !hasText {
                Image(nsImage: icon)
            }
            if hasText {
                Text(labelText)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    private var labelText: String {
        var parts: [String] = []
        if showLatency {
            if let latency = monitor.lastLatencyMs, !monitor.lastFailed {
                parts.append("\(Int(latency.rounded()))ms")
            } else {
                parts.append("—")
            }
        }
        if showLossPercent {
            let loss = Int(monitor.lossPercent.rounded())
            parts.append("(\(loss)%)")
        }
        return parts.joined(separator: " ")
    }
}
