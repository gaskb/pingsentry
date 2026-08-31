import SwiftUI

struct StatsView: View {
    @ObservedObject var monitor: PingMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(monitor.host)
                .font(.headline)

            statsBlock(title: "Sessione corrente", stats: monitor.sessionStats)
            Divider()
            statsBlock(title: "Lifetime (per questo host)", stats: monitor.lifetimeStats)

            Spacer()
        }
        .padding(20)
        .frame(width: 320, height: 360)
    }

    private func statsBlock(title: String, stats: PingStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).bold()
            row("Ping totali", "\(stats.totalCount)")
            row("Con risposta", "\(stats.successCount) (\(percentString(stats.successPercent)))")
            row("Senza risposta", "\(stats.failureCount) (\(percentString(stats.failurePercent)))")
            row("Media", msString(stats.averageLatency))
            row("Più veloce", msString(stats.minLatency))
            row("Più lento", msString(stats.maxLatency))
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
