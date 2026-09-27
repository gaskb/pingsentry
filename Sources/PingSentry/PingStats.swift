import Foundation

struct PingStats: Codable {
    private(set) var totalCount: Int = 0
    private(set) var successCount: Int = 0
    private(set) var failureCount: Int = 0
    private(set) var minLatency: Double?
    private(set) var maxLatency: Double?
    private var latencySum: Double = 0

    mutating func record(_ result: PingResult) {
        totalCount += 1
        if result.success, let latency = result.latencyMs {
            successCount += 1
            latencySum += latency
            minLatency = min(minLatency ?? latency, latency)
            maxLatency = max(maxLatency ?? latency, latency)
        } else {
            failureCount += 1
        }
    }

    var successPercent: Double {
        totalCount == 0 ? 0 : Double(successCount) / Double(totalCount) * 100
    }

    var failurePercent: Double {
        totalCount == 0 ? 0 : Double(failureCount) / Double(totalCount) * 100
    }

    var averageLatency: Double? {
        successCount == 0 ? nil : latencySum / Double(successCount)
    }
}

@MainActor
final class LifetimeStatsStore {
    static let shared = LifetimeStatsStore()
    private static let key = "lifetimeStatsByHost"

    private var cache: [String: PingStats]?
    private var isDirty = false
    private var flushTimer: Timer?

    private init() {}

    static func load(for host: String) -> PingStats {
        shared.load(for: host)
    }

    static func save(_ stats: PingStats, for host: String) {
        shared.save(stats, for: host)
    }

    static func flush() {
        shared.flush()
    }

    func load(for host: String) -> PingStats {
        loadCacheIfNeeded()
        return cache?[host] ?? PingStats()
    }

    func save(_ stats: PingStats, for host: String) {
        loadCacheIfNeeded()
        cache?[host] = stats
        isDirty = true
        scheduleDebouncedFlush()
    }

    func flush() {
        guard isDirty, let cache else { return }
        flushTimer?.invalidate()
        flushTimer = nil
        if let encoded = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(encoded, forKey: Self.key)
        }
        isDirty = false
    }

    private func loadCacheIfNeeded() {
        guard cache == nil else { return }
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([String: PingStats].self, from: data) {
            cache = decoded
        } else {
            cache = [:]
        }
    }

    private func scheduleDebouncedFlush(interval: TimeInterval = 30.0) {
        guard flushTimer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flush()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        flushTimer = timer
    }
}
