import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var monitor: PingMonitor

    @AppStorage("host") private var host: String = "1.1.1.1"
    @AppStorage("intervalSeconds") private var intervalSeconds: Double = 2.0
    @AppStorage("windowSize") private var windowSize: Int = 20
    @AppStorage("showLatency") private var showLatency: Bool = true
    @AppStorage("showLossPercent") private var showLossPercent: Bool = true
    @AppStorage("showBarsIcon") private var showBarsIcon: Bool = true
    @AppStorage("notifyOnStateChange") private var notifyOnStateChange: Bool = true
    @AppStorage(Localization.appLanguageDefaultsKey) private var appLanguage: String = AppLanguage.system.rawValue

    @State private var hostDraft: String = ""
    @State private var launchAtLoginEnabled = false
    @State private var loginItemError: String?
    @State private var notificationAuthStatus: UNAuthorizationStatus = .authorized

    var body: some View {
        Form {
            Section(L("settings.section.connection")) {
                HStack {
                    TextField(L("settings.host_placeholder"), text: $hostDraft)
                        .onSubmit(applyHost)
                    Button(L("settings.apply"), action: applyHost)
                }
                Stepper(L("settings.interval_format", Int(intervalSeconds)), value: $intervalSeconds, in: 1...60)
                Stepper(L("settings.window_format", windowSize), value: $windowSize, in: 5...100, step: 5)
            }

            Section(L("settings.section.display")) {
                Toggle(L("settings.show_bars"), isOn: $showBarsIcon)
                Toggle(L("settings.show_latency"), isOn: $showLatency)
                Toggle(L("settings.show_loss"), isOn: $showLossPercent)
            }

            Section(L("settings.section.notifications")) {
                Toggle(L("settings.notify_toggle"), isOn: $notifyOnStateChange)
                    .onChange(of: notifyOnStateChange) { _, newValue in
                        monitor.notifyOnStateChange = newValue
                        if newValue {
                            NotificationManager.requestAuthorizationIfNeeded()
                            Task {
                                await refreshNotificationAuth()
                            }
                        }
                    }

                if notifyOnStateChange && notificationAuthStatus == .denied {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("settings.notifications_denied_warning"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button(L("settings.open_system_settings")) {
                            NotificationManager.openSystemNotificationSettings()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }

            Section(L("settings.section.startup")) {
                Toggle(L("settings.launch_at_login"), isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { _, newValue in
                        do {
                            try LoginItemManager.setEnabled(newValue)
                            loginItemError = nil
                        } catch {
                            loginItemError = L("settings.login_item_error_format", error.localizedDescription)
                            launchAtLoginEnabled = LoginItemManager.isEnabled
                        }
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(L("settings.section.language")) {
                Picker(L("settings.section.language"), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 500)
        .onAppear {
            hostDraft = host
            launchAtLoginEnabled = LoginItemManager.isEnabled
        }
        .task {
            await refreshNotificationAuth()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await refreshNotificationAuth()
            }
        }
        .onChange(of: intervalSeconds) { _, newValue in
            monitor.intervalSeconds = newValue
            monitor.restart()
        }
        .onChange(of: windowSize) { _, newValue in
            monitor.windowSize = newValue
        }
    }

    private func refreshNotificationAuth() async {
        notificationAuthStatus = await NotificationManager.checkAuthorizationStatus()
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
