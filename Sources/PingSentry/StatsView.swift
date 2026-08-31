import SwiftUI

struct StatsView: View {
    @ObservedObject var monitor: PingMonitor
    @AppStorage(Localization.appLanguageDefaultsKey) private var appLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(monitor.host)
                .font(.headline)

            statsBlock(title: L("stats.current_session"), stats: monitor.sessionStats)
            Divider()
            statsBlock(title: L("stats.lifetime"), stats: monitor.lifetimeStats)

            Spacer()
        }
        .padding(20)
        .frame(width: 320, height: 360)
    }

    private func statsBlock(title: String, stats: PingStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).bold()
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
