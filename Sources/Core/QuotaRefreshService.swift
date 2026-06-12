import AppKit
import Foundation

@MainActor
public protocol QuotaRefreshServiceDelegate: AnyObject {
    func quotaRefreshServiceDidUpdate(_ service: QuotaRefreshService)
}

@MainActor
public final class QuotaRefreshService {
    public weak var delegate: QuotaRefreshServiceDelegate?
    public private(set) var snapshot: CodexQuotaSnapshot?
    public private(set) var lastError: Error?
    public private(set) var isRefreshing = false

    private let client: CodexRPCClient
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    public init(client: CodexRPCClient = CodexRPCClient()) {
        self.client = client
    }

    public func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    public func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        delegate?.quotaRefreshServiceDidUpdate(self)
        let client = self.client

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { try client.fetchQuota() }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                switch result {
                case .success(let snapshot):
                    self.snapshot = snapshot
                    self.lastError = nil
                case .failure(let error):
                    self.lastError = error
                }
                self.delegate?.quotaRefreshServiceDidUpdate(self)
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
    }
}
