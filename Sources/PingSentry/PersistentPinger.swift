import Foundation

enum MonitorState: Equatable, Sendable {
    case idle
    case running
    case retrying(attempt: Int, maxAttempts: Int, error: String, nextRetrySeconds: Int)
    case failed(error: String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

@MainActor
final class PersistentPinger {
    var onResult: ((PingResult) -> Void)?
    var onStateChanged: ((MonitorState) -> Void)?

    private var process: Process?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private(set) var lastErrorMessage: String?
    private var parser = PingOutputParser()
    private var currentSessionId = UUID()
    private var host = ""
    private var intervalSeconds: Double = 2
    private var retryCount = 0
    private let maxRetries = 5
    private var startTime: Date?
    private var retryTask: Task<Void, Never>?

    func start(host: String, intervalSeconds: Double) {
        retryCount = 0
        retryTask?.cancel()
        retryTask = nil
        launch(host: host, intervalSeconds: intervalSeconds)
    }

    private func launch(host: String, intervalSeconds: Double) {
        stop(keepRetryingState: false)
        let sessionId = UUID()
        self.currentSessionId = sessionId
        self.host = host
        self.intervalSeconds = intervalSeconds
        parser.reset()
        lastErrorMessage = nil
        startTime = Date()

        let validation = HostValidator.validate(host)
        guard validation.isValid else {
            let error = L(validation.errorMessageKey ?? "settings.host_invalid")
            onStateChanged?(.failed(error: error))
            return
        }

        let process = Process()
        process.executableURL = validation.executable.executableURL
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
            onStateChanged?(.running)
        } catch {
            scheduleRetry(errorDescription: error.localizedDescription, sessionId: sessionId)
        }
    }

    func stop() {
        stop(keepRetryingState: false)
        onStateChanged?(.idle)
    }

    private func stop(keepRetryingState: Bool) {
        currentSessionId = UUID()
        if !keepRetryingState {
            retryTask?.cancel()
            retryTask = nil
            retryCount = 0
        }
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

        let errorDesc = lastErrorMessage ?? L("state.failed")

        // If it ran continuously for > 10s before failing, give it full retry budget
        if let startTime, Date().timeIntervalSince(startTime) > 10 {
            retryCount = 0
        }

        scheduleRetry(errorDescription: errorDesc, sessionId: sessionId)
    }

    private func scheduleRetry(errorDescription: String, sessionId: UUID) {
        retryCount += 1
        if retryCount > maxRetries {
            onStateChanged?(.failed(error: errorDescription))
            return
        }

        let delaySeconds = min(Int(pow(2.0, Double(retryCount))), 30)
        onStateChanged?(.retrying(attempt: retryCount, maxAttempts: maxRetries, error: errorDescription, nextRetrySeconds: delaySeconds))

        let hostToRestart = host
        let intervalToRestart = intervalSeconds
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
            guard let self, self.currentSessionId == sessionId, !Task.isCancelled else { return }
            self.launch(host: hostToRestart, intervalSeconds: intervalToRestart)
        }
    }

    private func consume(_ chunk: String) {
        let results = parser.consume(chunk: chunk)
        if !results.isEmpty && retryCount > 0 {
            retryCount = 0
            onStateChanged?(.running)
        }
        for result in results {
            onResult?(result)
        }
    }
}
