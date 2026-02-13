import Foundation

// MARK: - Cloudflare Tunnel Manager

@MainActor
final class CloudflareTunnel {
    private var process: Process?
    private var outputPipe: Pipe?
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Check Installation

    nonisolated static func isInstalled() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["cloudflared"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    nonisolated static func cloudflaredPath() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["cloudflared"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        return nil
    }

    // MARK: - Start Tunnel

    func start() {
        if Self.isInstalled() {
            startTunnel()
        } else {
            appState?.tunnelStatus = .notInstalled
        }
    }

    private func startTunnel() {
        guard let appState = appState else { return }
        guard let cfPath = Self.cloudflaredPath() else {
            appState.tunnelStatus = .notInstalled
            return
        }

        // Stop any existing tunnel
        stopSync()

        appState.tunnelStatus = .starting

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: cfPath)
        proc.arguments = [
            "tunnel", "--url", "http://localhost:\(appState.config.port)"
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe  // cloudflared outputs URL on stderr

        outputPipe = pipe
        process = proc

        // Read output asynchronously to capture the tunnel URL
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let output = String(data: data, encoding: .utf8) ?? ""

            // Parse tunnel URL from cloudflared output
            // Pattern: "https://xxxxx.trycloudflare.com" or similar
            Task { @MainActor [weak self] in
                self?.parseTunnelOutput(output)
            }
        }

        // Handle process termination
        proc.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if proc.terminationStatus != 0 {
                    if case .starting = self.appState?.tunnelStatus {
                        self.appState?.tunnelStatus = .error("Process exited with code \(proc.terminationStatus)")
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
            // waitUntilExit() can block — use short timeout approach
            DispatchQueue.global().async {
                proc.waitUntilExit()
            }
        }
        process = nil
        outputPipe = nil
    }

    deinit {
        // nonisolated — avoid accessing @MainActor properties directly.
        // The terminationHandler or app lifecycle should have already stopped the process.
    }

    // MARK: - Parse Output

    private func parseTunnelOutput(_ output: String) {
        // cloudflared outputs lines like:
        // "INF +----------------------------+"
        // "INF |  https://xxx.trycloudflare.com  |"
        // OR: "INF Registered tunnel connection ... url=https://xxx.trycloudflare.com"
        // OR newer: just a URL in the output

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            // Look for HTTPS URL patterns
            if let range = line.range(of: "https://[a-zA-Z0-9\\-]+\\.trycloudflare\\.com", options: .regularExpression) {
                let url = String(line[range])
                appState?.tunnelStatus = .running(url: url)
                return
            }
            // Also match custom domain URLs from cloudflared
            if let range = line.range(of: "https://[a-zA-Z0-9\\-\\.]+", options: .regularExpression),
               line.contains("trycloudflare") || line.contains("cfargotunnel") {
                let url = String(line[range])
                appState?.tunnelStatus = .running(url: url)
                return
            }
        }
    }
}
