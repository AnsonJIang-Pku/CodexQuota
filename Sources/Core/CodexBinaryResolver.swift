import Foundation

public struct CodexBinaryResolver {
    public static let fallbackPaths = [
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
        "/Applications/Codex.app/Contents/Resources/codex"
    ]

    public init() {}

    public func resolve() throws -> URL {
        if let path = resolveFromPath() {
            return URL(fileURLWithPath: path)
        }

        for path in Self.fallbackPaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        throw CodexQuotaError.binaryNotFound
    }

    private func resolveFromPath() -> String? {
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in environmentPath.split(separator: ":").map(String.init) {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("codex").path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        // Match `which codex` semantics even when a GUI app inherited a sparse PATH.
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["codex"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return FileManager.default.isExecutableFile(atPath: path) ? path : nil
        } catch {
            return nil
        }
    }
}
