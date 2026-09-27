import Foundation

@MainActor
final class PersistentPinger {
    var onResult: ((PingResult) -> Void)?

    private var process: Process?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private(set) var lastErrorMessage: String?
    private var parser = PingOutputParser()
    private var currentSessionId = UUID()
    private var host = ""
    private var intervalSeconds: Double = 2

    func start(host: String, intervalSeconds: Double) {
        stop()
        let sessionId = UUID()
        self.currentSessionId = sessionId
        self.host = host
        self.intervalSeconds = intervalSeconds
        parser.reset()
        lastErrorMessage = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-i", String(format: "%.1f", max(intervalSeconds, 1)), host]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.currentSessionId == sessionId else { return }
                self.handleUnexpectedTermination(forSession: sessionId)
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                guard let self, self.currentSessionId == sessionId else { return }
                self.consume(chunk)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            Task { @MainActor [weak self] in
                guard let self, self.currentSessionId == sessionId else { return }
                self.lastErrorMessage = text
            }
        }

        do {
            try process.run()
            self.process = process
            self.outputHandle = pipe.fileHandleForReading
            self.errorHandle = errorPipe.fileHandleForReading
        } catch {
            onResult?(PingResult(timestamp: Date(), success: false, latencyMs: nil))
        }
    }

    func stop() {
        currentSessionId = UUID()
        outputHandle?.readabilityHandler = nil
        outputHandle = nil
        errorHandle?.readabilityHandler = nil
        errorHandle = nil
        if let process, process.isRunning {
            process.terminationHandler = nil
            process.terminate()
        }
        process = nil
    }

    private func handleUnexpectedTermination(forSession sessionId: UUID) {
        guard process != nil, currentSessionId == sessionId else { return }
        process = nil
        let hostToRestart = host
        let intervalToRestart = intervalSeconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, self.currentSessionId == sessionId else { return }
            self.start(host: hostToRestart, intervalSeconds: intervalToRestart)
        }
    }

    private func consume(_ chunk: String) {
        let results = parser.consume(chunk: chunk)
        for result in results {
            onResult?(result)
        }
    }
}
