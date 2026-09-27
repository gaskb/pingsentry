import Foundation

enum PingLineResult: Equatable, Sendable {
    case success(seq: Int, latencyMs: Double)
    case timeout(seq: Int)
    case ignored
}

struct PingOutputParser: Sendable {
    private(set) var buffer: String = ""
    private(set) var lastSeq: Int?
    let maxMissingPackets: Int

    init(maxMissingPackets: Int = 50) {
        self.maxMissingPackets = maxMissingPackets
    }

    mutating func reset() {
        buffer = ""
        lastSeq = nil
    }

    static func parseLine(_ line: String) -> PingLineResult {
        guard let seq = parseSeq(from: line) else {
            return .ignored
        }
        if let latency = parseLatency(from: line) {
            return .success(seq: seq, latencyMs: latency)
        } else {
            return .timeout(seq: seq)
        }
    }

    static func parseSeq(from line: String) -> Int? {
        let upperBound: String.Index
        if let range = line.range(of: "icmp_seq=") {
            upperBound = range.upperBound
        } else if let range = line.range(of: "icmp_seq ") {
            upperBound = range.upperBound
        } else {
            return nil
        }
        let after = line[upperBound...]
        let digits = after.prefix { $0.isNumber }
        return Int(digits)
    }

    static func parseLatency(from line: String) -> Double? {
        guard let range = line.range(of: "time=") else { return nil }
        let after = line[range.upperBound...]
        let numberPart = after.prefix { $0.isNumber || $0 == "." }
        return Double(numberPart)
    }

    mutating func consume(chunk: String, now: Date = Date()) -> [PingResult] {
        buffer += chunk
        var results: [PingResult] = []

        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            let lineResults = process(line: line, now: now)
            results.append(contentsOf: lineResults)
        }

        return results
    }

    mutating func process(line: String, now: Date = Date()) -> [PingResult] {
        let parsed = Self.parseLine(line)
        switch parsed {
        case .ignored:
            return []
        case .success(let seq, let latency):
            return handleSeq(seq, success: true, latency: latency, now: now)
        case .timeout(let seq):
            return handleSeq(seq, success: false, latency: nil, now: now)
        }
    }

    private mutating func handleSeq(_ seq: Int, success: Bool, latency: Double?, now: Date) -> [PingResult] {
        var results: [PingResult] = []
        if let lastSeq, seq > lastSeq + 1 {
            let missingCount = min(seq - lastSeq - 1, maxMissingPackets)
            for _ in 0..<missingCount {
                results.append(PingResult(timestamp: now, success: false, latencyMs: nil))
            }
        }
        lastSeq = seq
        results.append(PingResult(timestamp: now, success: success, latencyMs: latency))
        return results
    }
}
