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

enum LifetimeStatsStore {
    private static let key = "lifetimeStatsByHost"

    static func load(for host: String) -> PingStats {
        allStats()[host] ?? PingStats()
    }

    static func save(_ stats: PingStats, for host: String) {
        var dict = allStats()
        dict[host] = stats
        guard let encoded = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    private static func allStats() -> [String: PingStats] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: PingStats].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
