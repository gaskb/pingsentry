import SwiftUI

struct MenuContentView: View {
    @ObservedObject var monitor: PingMonitor
    @Binding var host: String
    @Binding var intervalSeconds: Double
    @Binding var windowSize: Int

    @State private var hostDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusSection
            Divider()
            settingsSection
            Divider()
            Button("Esci") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
        .onAppear {
            hostDraft = host
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monitor.host).font(.headline)
            if let latency = monitor.lastLatencyMs, !monitor.lastFailed {
                Text("Ultimo ping: \(String(format: "%.1f", latency)) ms")
            } else {
                Text("Ultimo ping: timeout")
                    .foregroundStyle(.red)
            }
            Text("Pacchetti persi: \(String(format: "%.0f", monitor.lossPercent))% (ultimi \(windowSize))")
                .foregroundStyle(.secondary)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Impostazioni").font(.subheadline).bold()

            HStack {
                TextField("es. 1.1.1.1", text: $hostDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(applyHost)
                Button("OK", action: applyHost)
            }

            Stepper(value: $intervalSeconds, in: 1...60, step: 1) {
                Text("Intervallo: \(Int(intervalSeconds)) s")
            }
            .onChange(of: intervalSeconds) { _, newValue in
                monitor.intervalSeconds = newValue
                monitor.restart()
            }

            Stepper(value: $windowSize, in: 5...100, step: 5) {
                Text("Finestra loss: \(windowSize) ping")
            }
            .onChange(of: windowSize) { _, newValue in
                monitor.windowSize = newValue
            }
        }
    }

    private func applyHost() {
        let trimmed = hostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        host = trimmed
        monitor.host = trimmed
        monitor.restart()
    }
}
