import SwiftUI

struct MenuContentView: View {
    @ObservedObject var monitor: PingMonitor
    @AppStorage(Localization.appLanguageDefaultsKey) private var appLanguage: String = AppLanguage.system.rawValue
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monitor.host).font(.headline)

            switch monitor.state {
            case .failed(let error):
                Text("\(L("state.failed")): \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                Button(L("menu.retry_now")) {
                    monitor.restart()
                }
            case .retrying(let attempt, let max, _, let nextSeconds):
                Text("\(L("state.retrying")) (\(attempt)/\(max)) · \(nextSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.orange)
            default:
                if let latency = monitor.lastLatencyMs, !monitor.lastFailed {
                    Text("\(L("menu.last_ping")): \(String(format: "%.1f", latency)) ms")
                } else {
                    Text("\(L("menu.last_ping")): \(L("menu.timeout"))")
                        .foregroundStyle(.red)
                }
                Text(L("menu.packet_loss_format", Int(monitor.lossPercent.rounded()), monitor.windowSize))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(L("menu.ping_now")) {
                monitor.pingNow()
            }

            Button(L("menu.stats")) {
                openWindow(id: "stats")
            }

            Button(L("menu.settings")) {
                openSettings()
            }
            .keyboardShortcut(",")

            Button(L("menu.about")) {
                openWindow(id: "about")
            }

            Divider()

            Button(L("menu.quit")) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
