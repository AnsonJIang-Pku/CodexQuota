import Foundation

public enum CodexQuotaError: LocalizedError {
    case binaryNotFound
    case permissionDenied(String)
    case appServerFailedToStart(String)
    case appServerExitedEarly(String)
    case notLoggedIn(String)
    case initializeTimeout
    case rateLimitsTimeout
    case invalidJSON(String)
    case rpcError(code: Int?, message: String)
    case rateLimitsMissing
    case primaryMissing
    case secondaryMissing
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Codex binary not found"
        case .permissionDenied(let detail):
            return "Permission denied: \(detail)"
        case .appServerFailedToStart(let detail):
            return "Codex app-server failed to start: \(detail)"
        case .appServerExitedEarly(let detail):
            return "Codex app-server exited early: \(detail)"
        case .notLoggedIn(let detail):
            return detail.isEmpty ? "Codex is not logged in" : "Codex is not logged in: \(detail)"
        case .initializeTimeout:
            return "JSON-RPC initialize timed out"
        case .rateLimitsTimeout:
            return "account/rateLimits/read timed out"
        case .invalidJSON(let detail):
            return "Invalid JSON from Codex app-server: \(detail)"
        case .rpcError(let code, let message):
            return code.map { "Codex RPC error \($0): \(message)" } ?? "Codex RPC error: \(message)"
        case .rateLimitsMissing:
            return "Codex response did not contain rateLimits"
        case .primaryMissing:
            return "Codex response did not contain the 5-hour quota"
        case .secondaryMissing:
            return "Codex response did not contain the weekly quota"
        case .writeFailed(let detail):
            return "Could not write to Codex app-server: \(detail)"
        }
    }
}
