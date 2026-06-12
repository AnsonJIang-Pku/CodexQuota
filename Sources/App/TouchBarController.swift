import AppKit
import CodexQuotaCore

extension NSTouchBarItem.Identifier {
    static let codexQuota = NSTouchBarItem.Identifier("com.openai.CodexQuotaTouchBar.quota")
}

final class CompactQuotaTouchBarView: NSView {
    private let primaryLabel = NSTextField(labelWithString: "5h --")
    private let secondaryLabel = NSTextField(labelWithString: "W --")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        for label in [primaryLabel, secondaryLabel] {
            label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            label.lineBreakMode = .byTruncatingTail
            label.alignment = .center
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            primaryLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            primaryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            secondaryLabel.leadingAnchor.constraint(equalTo: primaryLabel.trailingAnchor, constant: 12),
            secondaryLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            secondaryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            primaryLabel.widthAnchor.constraint(equalTo: secondaryLabel.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(snapshot: CodexQuotaSnapshot?, hasError: Bool) {
        guard let snapshot else {
            primaryLabel.stringValue = hasError ? "Codex err" : "5h --"
            secondaryLabel.stringValue = hasError ? "" : "W --"
            return
        }

        primaryLabel.stringValue = line(prefix: "5h", window: snapshot.primary)
        secondaryLabel.stringValue = line(prefix: "W ", window: snapshot.secondary)
    }

    private func line(prefix: String, window: CodexRateWindow?) -> String {
        guard let window else { return "\(prefix) --" }
        let percent = QuotaFormatting.percent(window.remainingPercent)
        let bar = QuotaFormatting.segmentedBar(remainingPercent: window.remainingPercent, segments: 5)
        let reset = QuotaFormatting.resetDescription(window.resetsAt, compact: true)
        return "\(prefix) \(percent) \(bar) \(reset)"
    }
}

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let quotaView = CompactQuotaTouchBarView(frame: .zero)

    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.codexQuota]
        touchBar.principalItemIdentifier = .codexQuota
        return touchBar
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == .codexQuota else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = quotaView
        item.customizationLabel = "Codex Quota"
        return item
    }

    func update(snapshot: CodexQuotaSnapshot?, hasError: Bool) {
        quotaView.update(snapshot: snapshot, hasError: hasError)
    }
}
