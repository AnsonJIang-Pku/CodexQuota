import CodexQuotaCore
import Foundation

let client = CodexRPCClient(timeouts: .init(initialize: 2.5, rateLimits: 2))

do {
    let snapshot = try client.fetchQuota()
    let primary = snapshot.primary.map { QuotaFormatting.percent($0.remainingPercent) } ?? "--"
    let secondary = snapshot.secondary.map { QuotaFormatting.percent($0.remainingPercent) } ?? "--"
    print("Cdx 5h \(primary) · W \(secondary)")
    exit(EXIT_SUCCESS)
} catch {
    print("Cdx --")
    exit(EXIT_FAILURE)
}
