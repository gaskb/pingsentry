import Foundation

@MainActor
final class PersistentPinger {
    var onResult: ((PingResult) -> Void)?

    private var process: Process?
    private var outputHandle: FileHandle?
    private var buffer = ""
    private var lastSeq: Int?
    private var host = ""
    private var intervalSeconds: Double = 2

    func start(host: String, intervalSeconds: Double) {
        stop()
        self.host = host
        self.intervalSeconds = intervalSeconds
        lastSeq = nil
        buffer = ""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-i", String(format: "%.1f", max(intervalSeconds, 1)), host]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleUnexpectedTermination()
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.consume(chunk)
            }
        }

        do {
            try process.run()
            self.process = process
            self.outputHandle = pipe.fileHandleForReading
        } catch {
            onResult?(PingResult(timestamp: Date(), success: false, latencyMs: nil))
        }
    }

    func stop() {
        outputHandle?.readabilityHandler = nil
        outputHandle = nil
        if let process, process.isRunning {
            process.terminationHandler = nil
            process.terminate()
        }
        process = nil
    }

    private func handleUnexpectedTermination() {
        guard process != nil else { return }
        process = nil
        let hostToRestart = host
        let intervalToRestart = intervalSeconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.start(host: hostToRestart, intervalSeconds: intervalToRestart)
        }
    }

    private func consume(_ chunk: String) {
        buffer += chunk
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            handle(line: line)
        }
    }

    private func handle(line: String) {
        guard let seq = Self.parseSeq(from: line) else { return }
        let latency = Self.parseLatency(from: line)

        if let lastSeq, seq > lastSeq + 1 {
            let missingCount = min(seq - lastSeq - 1, 50)
            for _ in 0..<missingCount {
                onResult?(PingResult(timestamp: Date(), success: false, latencyMs: nil))
            }
        }
        lastSeq = seq

        onResult?(PingResult(timestamp: Date(), success: latency != nil, latencyMs: latency))
    }

    nonisolated private static func parseSeq(from line: String) -> Int? {
        guard let range = line.range(of: "icmp_seq=") else { return nil }
        let after = line[range.upperBound...]
        let digits = after.prefix { $0.isNumber }
        return Int(digits)
    }

    nonisolated private static func parseLatency(from line: String) -> Double? {
        guard let range = line.range(of: "time=") else { return nil }
        let after = line[range.upperBound...]
        let numberPart = after.prefix { $0.isNumber || $0 == "." }
        return Double(numberPart)
    }
}
