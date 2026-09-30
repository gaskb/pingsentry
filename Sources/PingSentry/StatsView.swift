import SwiftUI

struct StatsView: View {
    @ObservedObject var monitor: PingMonitor
    @AppStorage(Localization.appLanguageDefaultsKey) private var appLanguage: String = AppLanguage.system.rawValue
    @State private var showingResetLifetimeConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(monitor.host)
                .font(.headline)

            statsBlock(title: L("stats.current_session"), stats: monitor.sessionStats) {
                Button(L("stats.reset_session")) {
                    monitor.resetSessionStats()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Divider()

            statsBlock(title: L("stats.lifetime"), stats: monitor.lifetimeStats) {
                Button(L("stats.reset_lifetime")) {
                    showingResetLifetimeConfirmation = true
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 340, height: 390)
        .confirmationDialog(
            L("stats.reset_lifetime_confirm"),
            isPresented: $showingResetLifetimeConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("stats.reset"), role: .destructive) {
                monitor.resetLifetimeStats()
            }
            Button(L("stats.cancel"), role: .cancel) {}
        }
    }

    private func statsBlock<Action: View>(
        title: String,
        stats: PingStats,
        @ViewBuilder headerAction: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline).bold()
                Spacer()
                headerAction()
            }
            row(L("stats.total"), "\(stats.totalCount)")
            row(L("stats.successful"), "\(stats.successCount) (\(percentString(stats.successPercent)))")
            row(L("stats.failed"), "\(stats.failureCount) (\(percentString(stats.failurePercent)))")
            row(L("stats.average"), msString(stats.averageLatency))
            row(L("stats.fastest"), msString(stats.minLatency))
            row(L("stats.slowest"), msString(stats.maxLatency))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private func percentString(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func msString(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f ms", value)
    }
}
