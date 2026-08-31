import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: PingMonitor

    @AppStorage("host") private var host: String = "1.1.1.1"
    @AppStorage("intervalSeconds") private var intervalSeconds: Double = 2.0
    @AppStorage("windowSize") private var windowSize: Int = 20
    @AppStorage("showLatency") private var showLatency: Bool = true
    @AppStorage("showLossPercent") private var showLossPercent: Bool = true
    @AppStorage("showBarsIcon") private var showBarsIcon: Bool = true
    @AppStorage("notifyOnStateChange") private var notifyOnStateChange: Bool = true

    @State private var hostDraft: String = ""
    @State private var launchAtLoginEnabled = false
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("Connessione") {
                HStack {
                    TextField("Host o IP", text: $hostDraft)
                        .onSubmit(applyHost)
                    Button("Applica", action: applyHost)
                }
                Stepper("Intervallo tra i ping: \(Int(intervalSeconds)) s", value: $intervalSeconds, in: 1...60)
                Stepper("Finestra calcolo perdita: \(windowSize) ping", value: $windowSize, in: 5...100, step: 5)
            }

            Section("Cosa mostrare in barra") {
                Toggle("Icona a barre", isOn: $showBarsIcon)
                Toggle("Latenza (ms)", isOn: $showLatency)
                Toggle("Percentuale pacchetti persi", isOn: $showLossPercent)
            }

            Section("Notifiche") {
                Toggle("Avvisa quando l'host non risponde o torna su", isOn: $notifyOnStateChange)
                    .onChange(of: notifyOnStateChange) { _, newValue in
                        monitor.notifyOnStateChange = newValue
                        if newValue {
                            NotificationManager.requestAuthorizationIfNeeded()
                        }
                    }
            }

            Section("Avvio") {
                Toggle("Avvia PingSentry al login", isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { _, newValue in
                        do {
                            try LoginItemManager.setEnabled(newValue)
                            loginItemError = nil
                        } catch {
                            loginItemError = "Non disponibile: \(error.localizedDescription)"
                            launchAtLoginEnabled = LoginItemManager.isEnabled
                        }
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 440)
        .onAppear {
            hostDraft = host
            launchAtLoginEnabled = LoginItemManager.isEnabled
        }
        .onChange(of: intervalSeconds) { _, newValue in
            monitor.intervalSeconds = newValue
            monitor.restart()
        }
        .onChange(of: windowSize) { _, newValue in
            monitor.windowSize = newValue
        }
    }

    private func applyHost() {
        let trimmed = hostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hostDraft = host
            return
        }
        host = trimmed
        monitor.changeHost(to: trimmed)
    }
}
