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

    var host: String
    var intervalSeconds: Double
    var windowSize: Int

    private var loopTask: Task<Void, Never>?
    private let maxHistory = 100

    init(host: String, intervalSeconds: Double, windowSize: Int) {
        self.host = host
        self.intervalSeconds = intervalSeconds
        self.windowSize = windowSize
    }

    func start() {
        stop()
        loopTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pingOnce()
                let delay = max(self.intervalSeconds, 1)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func restart() {
        start()
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

    private func pingOnce() async {
        let result = await Self.runPing(host: host)
        record(result)
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
    }

    nonisolated private static func runPing(host: String) async -> PingResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let now = Date()
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                process.arguments = ["-c", "1", "-t", "2", host]

                let outPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let latency = parseLatency(from: output)
                    let success = process.terminationStatus == 0 && latency != nil
                    continuation.resume(returning: PingResult(timestamp: now, success: success, latencyMs: latency))
                } catch {
                    continuation.resume(returning: PingResult(timestamp: now, success: false, latencyMs: nil))
                }
            }
        }
    }

    nonisolated private static func parseLatency(from output: String) -> Double? {
        guard let range = output.range(of: "time=") else { return nil }
        let after = output[range.upperBound...]
        let numberPart = after.prefix { $0.isNumber || $0 == "." }
        return Double(numberPart)
    }
}
