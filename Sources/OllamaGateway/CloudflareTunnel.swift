import Foundation

// MARK: - Cloudflare Tunnel Manager (Self-contained)

@MainActor
final class CloudflareTunnel {
    private var process: Process?
    private var outputPipe: Pipe?
    private weak var appState: AppState?

    /// Directory for storing the downloaded cloudflared binary
    nonisolated private static var supportDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OllamaGateway", isDirectory: true)
    }

    /// Path to the local cloudflared binary
    nonisolated private static var binaryPath: URL {
        supportDir.appendingPathComponent("cloudflared")
    }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Binary Management

    /// Check if cloudflared binary exists locally
    nonisolated static func isInstalled() -> Bool {
        FileManager.default.isExecutableFile(atPath: binaryPath.path)
    }

    /// Download cloudflared from GitHub Releases if not present
    private func ensureBinary() async throws {
        if Self.isInstalled() { return }

        appState?.tunnelStatus = .downloading

        // Determine architecture
        #if arch(arm64)
        let archSuffix = "arm64"
        #else
        let archSuffix = "amd64"
        #endif

        let urlString = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-\(archSuffix).tgz"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "CloudflareTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
        }

        // Create support directory
        try FileManager.default.createDirectory(at: Self.supportDir, withIntermediateDirectories: true)

        // Download
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let tgzPath = Self.supportDir.appendingPathComponent("cloudflared.tgz")

        // Move downloaded file
        if FileManager.default.fileExists(atPath: tgzPath.path) {
            try FileManager.default.removeItem(at: tgzPath)
        }
        try FileManager.default.moveItem(at: tempURL, to: tgzPath)

        // Extract with tar
        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-xzf", tgzPath.path, "-C", Self.supportDir.path]
        try tar.run()
        tar.waitUntilExit()

        guard tar.terminationStatus == 0 else {
            throw NSError(domain: "CloudflareTunnel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to extract cloudflared"])
        }

        // chmod +x
        let chmod = Process()
        chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmod.arguments = ["755", Self.binaryPath.path]
        try chmod.run()
        chmod.waitUntilExit()

        // Cleanup tgz
        try? FileManager.default.removeItem(at: tgzPath)

        guard Self.isInstalled() else {
            throw NSError(domain: "CloudflareTunnel", code: 3, userInfo: [NSLocalizedDescriptionKey: "cloudflared binary not found after extraction"])
        }
    }

    // MARK: - Start Tunnel

    func start() {
        Task {
            do {
                try await ensureBinary()
                startTunnel()
            } catch {
                appState?.tunnelStatus = .error(error.localizedDescription)
            }
        }
    }

    private func startTunnel() {
        guard let appState = appState else { return }

        // Stop any existing tunnel
        stopSync()

        appState.tunnelStatus = .starting

        let proc = Process()
        proc.executableURL = Self.binaryPath
        proc.arguments = [
            "tunnel", "--url", "http://localhost:\(appState.config.port)",
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        outputPipe = pipe
        process = proc

        // Read output asynchronously to capture the tunnel URL
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let output = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor [weak self] in
                self?.parseTunnelOutput(output)
            }
        }

        // Handle process termination
        proc.terminationHandler = { [weak self] terminatedProc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if terminatedProc.terminationStatus != 0 {
                    if case .starting = self.appState?.tunnelStatus {
                        self.appState?.tunnelStatus = .error(
                            "Process exited with code \(terminatedProc.terminationStatus)")
                    }
                } else {
                    self.appState?.tunnelStatus = .stopped
                }
                self.process = nil
                self.outputPipe = nil
            }
        }

        do {
            try proc.run()
        } catch {
            appState.tunnelStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Stop Tunnel

    func stop() {
        stopSync()
        appState?.tunnelStatus = .stopped
    }

    private func stopSync() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        process = nil
        outputPipe = nil
    }

    // MARK: - Parse Output

    private func parseTunnelOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if let range = line.range(
                of: "https://[a-zA-Z0-9\\-]+\\.trycloudflare\\.com", options: .regularExpression)
            {
                let url = String(line[range])
                appState?.tunnelStatus = .running(url: url)
                return
            }
            if let range = line.range(
                of: "https://[a-zA-Z0-9\\-\\.]+", options: .regularExpression),
                line.contains("trycloudflare") || line.contains("cfargotunnel")
            {
                let url = String(line[range])
                appState?.tunnelStatus = .running(url: url)
                return
            }
        }
    }
}
