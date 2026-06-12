import AppKit
import CodexQuotaCore

@MainActor
final class MenuBarController: NSObject, QuotaRefreshServiceDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let refreshService: QuotaRefreshService
    private let touchBarController = TouchBarController()
    private var touchBarWindow: NSWindow?
    private let touchBarWindowLabel = NSTextField(wrappingLabelWithString: "")

    init(refreshService: QuotaRefreshService) {
        self.refreshService = refreshService
        super.init()
        refreshService.delegate = self
        configureStatusItem()
        rebuildMenu()
        touchBarController.update(snapshot: nil, hasError: false)
    }

    func start() {
        refreshService.start()
    }

    func quotaRefreshServiceDidUpdate(_ service: QuotaRefreshService) {
        updateStatusTitle()
        touchBarController.update(snapshot: service.snapshot, hasError: service.lastError != nil)
        rebuildMenu()
        updateTouchBarWindowText()
    }

    private func configureStatusItem() {
        statusItem.button?.title = "Codex --"
        statusItem.button?.toolTip = "Codex quota"
    }

    private func updateStatusTitle() {
        guard let snapshot = refreshService.snapshot else {
            statusItem.button?.title = refreshService.isRefreshing ? "Codex …" : "Codex --"
            return
        }
        let primary = snapshot.primary.map { QuotaFormatting.percent($0.remainingPercent) } ?? "--"
        let secondary = snapshot.secondary.map { QuotaFormatting.percent($0.remainingPercent) } ?? "--"
        statusItem.button?.title = "Codex \(primary.replacingOccurrences(of: "%", with: ""))·\(secondary.replacingOccurrences(of: "%", with: ""))"
        statusItem.button?.toolTip = "Codex quota: 5h \(primary) left, weekly \(secondary) left"
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let heading = NSMenuItem(title: "Codex Quota", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())

        if let snapshot = refreshService.snapshot {
            menu.addItem(quotaItem(window: snapshot.primary, title: "5h quota"))
            menu.addItem(quotaItem(window: snapshot.secondary, title: "Weekly quota"))
            menu.addItem(.separator())

            let updated = NSMenuItem(
                title: "Last updated: \(QuotaFormatting.updatedTime(snapshot.fetchedAt))",
                action: nil,
                keyEquivalent: ""
            )
            updated.isEnabled = false
            menu.addItem(updated)
        } else {
            let loading = NSMenuItem(
                title: refreshService.isRefreshing ? "Codex quota loading..." : "No quota data",
                action: nil,
                keyEquivalent: ""
            )
            loading.isEnabled = false
            menu.addItem(loading)
        }

        if let error = refreshService.lastError {
            let item = NSMenuItem(
                title: "Last error: \(error.localizedDescription)",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            item.toolTip = error.localizedDescription
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let refresh = NSMenuItem(
            title: refreshService.isRefreshing ? "Refreshing..." : "Refresh Now",
            action: #selector(refreshNow),
            keyEquivalent: "r"
        )
        refresh.target = self
        refresh.isEnabled = !refreshService.isRefreshing
        menu.addItem(refresh)

        let touchBar = NSMenuItem(
            title: "Show Touch Bar Window",
            action: #selector(showTouchBarWindow),
            keyEquivalent: "t"
        )
        touchBar.target = self
        menu.addItem(touchBar)

        let openCodex = NSMenuItem(
            title: "Open Codex",
            action: #selector(openCodex),
            keyEquivalent: ""
        )
        openCodex.target = self
        menu.addItem(openCodex)

        menu.addItem(.separator())
        let developer = NSMenuItem(
            title: "Developer: HoshinoJiang",
            action: nil,
            keyEquivalent: ""
        )
        developer.isEnabled = false
        menu.addItem(developer)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func quotaItem(window: CodexRateWindow?, title: String) -> NSMenuItem {
        let view = QuotaBarView(frame: NSRect(x: 0, y: 0, width: 330, height: 70))
        view.update(window: window, title: title)
        let item = NSMenuItem()
        item.view = view
        return item
    }

    @objc private func refreshNow() {
        refreshService.refresh()
    }

    @objc private func openCodex() {
        let appURL = URL(fileURLWithPath: "/Applications/Codex.app")
        if FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
        }
    }

    @objc private func showTouchBarWindow() {
        if touchBarWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Codex Quota Touch Bar"
            window.center()
            window.isReleasedWhenClosed = false
            window.touchBar = touchBarController.makeTouchBar()
            configureTouchBarWindowContent(window)
            touchBarWindow = window
        }
        updateTouchBarWindowText()
        touchBarWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateTouchBarWindowText() {
        guard touchBarWindow != nil else { return }
        let text: String
        if let snapshot = refreshService.snapshot {
            let primary = snapshot.primary.map { QuotaFormatting.percent($0.remainingPercent) } ?? "--"
            let secondary = snapshot.secondary.map { QuotaFormatting.percent($0.remainingPercent) } ?? "--"
            text = "Focus this window to show the native Touch Bar.\n5h \(primary) left · Weekly \(secondary) left"
        } else {
            text = refreshService.lastError == nil ? "Codex quota loading..." : "Codex quota unavailable"
        }
        touchBarWindowLabel.stringValue = text
    }

    private func configureTouchBarWindowContent(_ window: NSWindow) {
        touchBarWindowLabel.alignment = .center
        touchBarWindowLabel.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(touchBarWindowLabel)
        NSLayoutConstraint.activate([
            touchBarWindowLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            touchBarWindowLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            touchBarWindowLabel.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 20),
            touchBarWindowLabel.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20)
        ])
        window.contentView = content
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
