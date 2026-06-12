import AppKit
import CodexQuotaCore

final class QuotaBarView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let resetLabel = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        percentLabel.alignment = .right
        resetLabel.font = .systemFont(ofSize: 11)
        resetLabel.textColor = .secondaryLabelColor

        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 100
        progress.controlSize = .small
        progress.style = .bar

        [titleLabel, percentLabel, progress, resetLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 70),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            percentLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            progress.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: percentLabel.trailingAnchor),
            progress.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            resetLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            resetLabel.topAnchor.constraint(equalTo: progress.bottomAnchor, constant: 4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(window: CodexRateWindow?, title: String) {
        titleLabel.stringValue = title
        guard let window else {
            percentLabel.stringValue = "--"
            progress.doubleValue = 0
            resetLabel.stringValue = "quota unavailable"
            return
        }
        percentLabel.stringValue = "\(QuotaFormatting.percent(window.remainingPercent)) left"
        progress.doubleValue = window.remainingPercent
        resetLabel.stringValue = QuotaFormatting.resetDescription(window.resetsAt)
    }
}
