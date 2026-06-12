import Foundation

public final class CodexRPCClient: @unchecked Sendable {
    public struct Timeouts: Sendable {
        public let initialize: TimeInterval
        public let rateLimits: TimeInterval

        public init(initialize: TimeInterval = 8, rateLimits: TimeInterval = 5) {
            self.initialize = initialize
            self.rateLimits = rateLimits
        }
    }

    private let resolver: CodexBinaryResolver
    private let timeouts: Timeouts

    public init(
        resolver: CodexBinaryResolver = CodexBinaryResolver(),
        timeouts: Timeouts = Timeouts()
    ) {
        self.resolver = resolver
        self.timeouts = timeouts
    }

    public func fetchQuota() throws -> CodexQuotaSnapshot {
        let binaryURL = try resolver.resolve()
        do {
            return try runSession(binaryURL: binaryURL, includeListenArgument: true)
        } catch {
            guard shouldRetryWithoutListen(error) else { throw error }
            return try runSession(binaryURL: binaryURL, includeListenArgument: false)
        }
    }

    private func runSession(binaryURL: URL, includeListenArgument: Bool) throws -> CodexQuotaSnapshot {
        let session = RPCSession(binaryURL: binaryURL, includeListenArgument: includeListenArgument)
        defer { session.stop() }

        try session.start()
        try session.send([
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "CodexQuotaTouchBar",
                    "version": "0.1.0"
                ]
            ]
        ])
        _ = try session.waitForResponse(id: 1, timeout: timeouts.initialize, timeoutError: .initializeTimeout)

        try session.send(["method": "initialized", "params": [:]])
        try session.send(["id": 2, "method": "account/rateLimits/read", "params": [:]])
        let response = try session.waitForResponse(
            id: 2,
            timeout: timeouts.rateLimits,
            timeoutError: .rateLimitsTimeout
        )
        return try CodexQuotaParser.parse(response: response)
    }

    private func shouldRetryWithoutListen(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("--listen")
            && (message.contains("unexpected") || message.contains("unknown") || message.contains("unrecognized"))
    }
}

private final class RPCSession {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let condition = NSCondition()
    private let binaryURL: URL
    private let includeListenArgument: Bool

    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()
    private var responses: [Int: [String: Any]] = [:]
    private var parseError: Error?
    private var didExit = false
    private var stopped = false

    init(binaryURL: URL, includeListenArgument: Bool) {
        self.binaryURL = binaryURL
        self.includeListenArgument = includeListenArgument
    }

    func start() throws {
        process.executableURL = binaryURL
        var arguments = ["-s", "read-only", "-a", "untrusted", "app-server"]
        if includeListenArgument {
            arguments += ["--listen", "stdio://"]
        }
        process.arguments = arguments
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeStdout(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeStderr(handle.availableData)
        }
        process.terminationHandler = { [weak self] _ in
            guard let self else { return }
            self.condition.lock()
            self.didExit = true
            self.condition.broadcast()
            self.condition.unlock()
        }

        do {
            try process.run()
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            throw CodexQuotaError.permissionDenied(error.localizedDescription)
        } catch {
            let message = error.localizedDescription
            if message.lowercased().contains("permission") {
                throw CodexQuotaError.permissionDenied(message)
            }
            throw CodexQuotaError.appServerFailedToStart(message)
        }
    }

    func send(_ object: [String: Any]) throws {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: object)
        } catch {
            throw CodexQuotaError.invalidJSON(error.localizedDescription)
        }

        var line = data
        line.append(0x0A)
        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: line)
        } catch {
            throw CodexQuotaError.writeFailed(error.localizedDescription)
        }
    }

    func waitForResponse(
        id: Int,
        timeout: TimeInterval,
        timeoutError: CodexQuotaError
    ) throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }

        while responses[id] == nil && parseError == nil && !didExit {
            if !condition.wait(until: deadline) {
                throw timeoutError
            }
        }

        if let parseError { throw parseError }
        guard let response = responses.removeValue(forKey: id) else {
            let detail = stderrText()
            throw classifyEarlyExit(detail)
        }
        if let error = response["error"] as? [String: Any] {
            let code = (error["code"] as? NSNumber)?.intValue
            let message = (error["message"] as? String) ?? "Unknown error"
            if message.lowercased().contains("login") || message.lowercased().contains("auth") {
                throw CodexQuotaError.notLoggedIn(message)
            }
            throw CodexQuotaError.rpcError(code: code, message: message)
        }
        return response
    }

    func stop() {
        condition.lock()
        if stopped {
            condition.unlock()
            return
        }
        stopped = true
        condition.unlock()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        try? stdinPipe.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
            let deadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()
        process.terminationHandler = nil
    }

    private func consumeStdout(_ data: Data) {
        guard !data.isEmpty else { return }
        condition.lock()
        stdoutBuffer.append(data)

        while let newline = stdoutBuffer.firstIndex(of: 0x0A) {
            let line = stdoutBuffer[..<newline]
            stdoutBuffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            do {
                let object = try JSONSerialization.jsonObject(with: Data(line))
                guard let dictionary = object as? [String: Any] else {
                    throw CodexQuotaError.invalidJSON("top-level value is not an object")
                }
                if let id = (dictionary["id"] as? NSNumber)?.intValue {
                    responses[id] = dictionary
                }
            } catch {
                parseError = CodexQuotaError.invalidJSON(
                    String(decoding: line.prefix(240), as: UTF8.self)
                )
            }
        }
        condition.broadcast()
        condition.unlock()
    }

    private func consumeStderr(_ data: Data) {
        guard !data.isEmpty else { return }
        condition.lock()
        if stderrBuffer.count < 16_384 {
            stderrBuffer.append(data.prefix(16_384 - stderrBuffer.count))
        }
        condition.unlock()
    }

    private func stderrText() -> String {
        String(decoding: stderrBuffer, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func classifyEarlyExit(_ detail: String) -> CodexQuotaError {
        let lower = detail.lowercased()
        if lower.contains("permission denied") || lower.contains("readonly database") {
            return .permissionDenied(detail)
        }
        if lower.contains("not logged") || lower.contains("authentication") || lower.contains("login") {
            return .notLoggedIn(detail)
        }
        return .appServerExitedEarly(detail.isEmpty ? "process terminated without a response" : detail)
    }
}
