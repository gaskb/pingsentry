import AppKit
import Foundation

struct PingResult: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let success: Bool
    let latencyMs: Double?
}

enum SignalQuality: Int, CaseIterable {
    case none = 0, poor, fair, good, excellent

    var bars: Int { rawValue }
}

@MainActor
final class PingMonitor: ObservableObject {
    @Published private(set) var history: [PingResult] = []
    @Published private(set) var lastLatencyMs: Double?
    @Published private(set) var lossPercent: Double = 0
    @Published private(set) var lastFailed: Bool = false
    @Published private(set) var sessionStats = PingStats()
    @Published private(set) var lifetimeStats = PingStats()

    private(set) var host: String
    var intervalSeconds: Double
    var windowSize: Int
    var notifyOnStateChange: Bool = true

    private let pinger = PersistentPinger()
    private let maxHistory = 100
    private let downThreshold = 3
    private var consecutiveFailures = 0
    private var hasNotifiedDown = false

    private var sleepToken: NotificationToken?
    private var wakeToken: NotificationToken?
    private var isSystemSleeping = false
    private var wasRunningBeforeSleep = false

    init(host: String, intervalSeconds: Double, windowSize: Int) {
        self.host = host
        self.intervalSeconds = intervalSeconds
        self.windowSize = windowSize
        self.lifetimeStats = LifetimeStatsStore.load(for: host)
        setupSleepWakeObservers()
    }

    func changeHost(to newHost: String) {
        guard newHost != host else { return }
        LifetimeStatsStore.flush()
        host = newHost
        sessionStats = PingStats()
        lifetimeStats = LifetimeStatsStore.load(for: newHost)
        restart()
    }

    func start() {
        consecutiveFailures = 0
        hasNotifiedDown = false
        pinger.onResult = { [weak self] result in
            self?.record(result)
        }
        pinger.start(host: host, intervalSeconds: intervalSeconds)
    }

    func stop() {
        pinger.stop()
        LifetimeStatsStore.flush()
    }

    func restart() {
        stop()
        start()
    }

    func pingNow() {
        restart()
    }

    var quality: SignalQuality {
        if lossPercent >= 50 { return .none }
        guard !lastFailed, let latency = lastLatencyMs else {
            return .poor
        }
        if lossPercent >= 20 { return .poor }
        switch latency {
        case ..<30: return .excellent
        case ..<80: return .good
        case ..<150: return .fair
        default: return .poor
        }
    }

    private func record(_ result: PingResult) {
        history.append(result)
        if history.count > maxHistory {
            history.removeFirst(history.count - maxHistory)
        }
        lastLatencyMs = result.latencyMs
        lastFailed = !result.success

        let window = history.suffix(max(windowSize, 1))
        let failures = window.filter { !$0.success }.count
        lossPercent = window.isEmpty ? 0 : (Double(failures) / Double(window.count)) * 100.0

        sessionStats.record(result)
        lifetimeStats.record(result)
        LifetimeStatsStore.save(lifetimeStats, for: host)

        handleStateChange(success: result.success)
    }

    private func handleStateChange(success: Bool) {
        let currentHost = host
        if success {
            consecutiveFailures = 0
            if hasNotifiedDown {
                hasNotifiedDown = false
                if notifyOnStateChange {
                    NotificationManager.send(
                        title: "PingSentry",
                        body: L("notification.host_up_format", currentHost)
                    )
                }
            }
        } else {
            consecutiveFailures += 1
            if consecutiveFailures >= downThreshold && !hasNotifiedDown {
                hasNotifiedDown = true
                if notifyOnStateChange {
                    NotificationManager.send(
                        title: "PingSentry",
                        body: L("notification.host_down_format", currentHost, downThreshold)
                    )
                }
            }
        }
    }

    private func setupSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let sleep = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemWillSleep()
            }
        }
        sleepToken = NotificationToken(token: sleep, center: center)

        let wake = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemDidWake()
            }
        }
        wakeToken = NotificationToken(token: wake, center: center)
    }

    private func handleSystemWillSleep() {
        isSystemSleeping = true
        wasRunningBeforeSleep = true
        consecutiveFailures = 0
        pinger.stop()
        LifetimeStatsStore.flush()
    }

    private func handleSystemDidWake() {
        guard isSystemSleeping else { return }
        isSystemSleeping = false
        consecutiveFailures = 0
        guard wasRunningBeforeSleep else { return }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self, !self.isSystemSleeping else { return }
            self.start()
        }
    }
}

private final class NotificationToken: @unchecked Sendable {
    private let token: any NSObjectProtocol
    private let center: NotificationCenter

    init(token: any NSObjectProtocol, center: NotificationCenter) {
        self.token = token
        self.center = center
    }

    deinit {
        center.removeObserver(token)
    }
}
