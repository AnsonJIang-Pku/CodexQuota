import Foundation

public enum QuotaFormatting {
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func segmentedBar(remainingPercent: Double, segments: Int = 10) -> String {
        let filled = min(segments, max(0, Int((remainingPercent / 100 * Double(segments)).rounded())))
        return String(repeating: "▰", count: filled) + String(repeating: "▱", count: segments - filled)
    }

    public static func resetDescription(_ date: Date?, now: Date = Date(), compact: Bool = false) -> String {
        guard let date else { return compact ? "--" : "reset time unavailable" }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return compact ? "now" : "reset due now" }

        let totalMinutes = Int(interval / 60)
        if totalMinutes < 24 * 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if compact {
                return hours > 0 ? "\(hours)h\(minutes)m" : "\(minutes)m"
            }
            return hours > 0 ? "resets in \(hours)h \(minutes)m" : "resets in \(minutes)m"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = compact ? "EEE" : "EEE HH:mm"
        return compact ? formatter.string(from: date) : "resets \(formatter.string(from: date))"
    }

    public static func updatedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
