import Foundation

public struct CodexRateWindow: Equatable, Sendable {
    public let usedPercent: Double
    public let remainingPercent: Double
    public let windowDurationMins: Int?
    public let resetsAt: Date?
    public let label: String

    public init(
        usedPercent: Double,
        windowDurationMins: Int?,
        resetsAt: Date?,
        label: String
    ) {
        self.usedPercent = min(100, max(0, usedPercent))
        self.remainingPercent = max(0, 100 - self.usedPercent)
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
        self.label = label
    }
}

public struct CodexQuotaSnapshot: Equatable, Sendable {
    public let primary: CodexRateWindow?
    public let secondary: CodexRateWindow?
    public let fetchedAt: Date
    public let accountEmail: String?
    public let planType: String?

    public init(
        primary: CodexRateWindow?,
        secondary: CodexRateWindow?,
        fetchedAt: Date = Date(),
        accountEmail: String?,
        planType: String?
    ) {
        self.primary = primary
        self.secondary = secondary
        self.fetchedAt = fetchedAt
        self.accountEmail = accountEmail
        self.planType = planType
    }
}

public enum CodexQuotaParser {
    public static func parse(response: [String: Any], fetchedAt: Date = Date()) throws -> CodexQuotaSnapshot {
        guard let result = response["result"] as? [String: Any] else {
            throw CodexQuotaError.rateLimitsMissing
        }

        let rateLimits: [String: Any]
        if let nested = dictionary(result["rateLimits"]) {
            rateLimits = nested
        } else if result["primary"] != nil || result["secondary"] != nil {
            rateLimits = result
        } else {
            throw CodexQuotaError.rateLimitsMissing
        }

        let primary = parseWindow(
            dictionary(rateLimits["primary"]),
            defaultLabel: "5h",
            durationFallback: 300
        )
        let secondary = parseWindow(
            dictionary(rateLimits["secondary"]),
            defaultLabel: "Weekly",
            durationFallback: 10_080
        )

        guard primary != nil || secondary != nil else {
            throw CodexQuotaError.primaryMissing
        }

        let account = dictionary(result["account"])
            ?? dictionary(rateLimits["account"])
            ?? [:]
        let email = string(result["accountEmail"])
            ?? string(result["email"])
            ?? string(account["email"])
        let plan = string(result["planType"])
            ?? string(result["plan"])
            ?? string(account["planType"])
            ?? string(account["plan"])

        return CodexQuotaSnapshot(
            primary: primary,
            secondary: secondary,
            fetchedAt: fetchedAt,
            accountEmail: email,
            planType: plan
        )
    }

    private static func parseWindow(
        _ value: [String: Any]?,
        defaultLabel: String,
        durationFallback: Int
    ) -> CodexRateWindow? {
        guard let value, let used = number(value["usedPercent"] ?? value["used_percent"]) else {
            return nil
        }

        let duration = integer(value["windowDurationMins"] ?? value["window_duration_mins"])
        let reset = date(value["resetsAt"] ?? value["resets_at"])
        let label = string(value["label"])
            ?? labelFor(duration: duration ?? durationFallback, fallback: defaultLabel)

        return CodexRateWindow(
            usedPercent: used,
            windowDurationMins: duration,
            resetsAt: reset,
            label: label
        )
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty { return value }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func integer(_ value: Any?) -> Int? {
        number(value).map { Int($0) }
    }

    private static func date(_ value: Any?) -> Date? {
        if let seconds = number(value) {
            return Date(timeIntervalSince1970: seconds)
        }
        if let text = string(value) {
            return ISO8601DateFormatter().date(from: text)
        }
        return nil
    }

    private static func labelFor(duration: Int, fallback: String) -> String {
        if duration == 300 { return "5h" }
        if duration >= 10_000 { return "Weekly" }
        return fallback
    }
}
