import Foundation
import ServiceManagement

// MARK: - Health Checker

@MainActor
final class HealthChecker {
    private var timer: Timer?
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.check()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func check() {
        guard let appState = appState else { return }
        let urlStr = appState.config.ollamaBaseURL
        guard let url = URL(string: urlStr) else {
            appState.ollamaStatus = .offline
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak appState] _, response, error in
            Task { @MainActor [weak appState] in
                guard let appState = appState else { return }
                if error == nil, let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    appState.ollamaStatus = .online
                } else {
                    appState.ollamaStatus = .offline
                }
            }
        }.resume()
    }
}

// MARK: - Update Checker

struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
    let prerelease: Bool
    let draft: Bool
    let assets: [GitHubAsset]?

    struct GitHubAsset: Codable {
        let name: String
        let browser_download_url: String
    }
}

@MainActor
final class UpdateChecker {
    private var timer: Timer?
    private weak var appState: AppState?

    // ⚠️ 配置你的 GitHub 仓库
    static let repoOwner = "OWNER"
    static let repoName = "ollamafastapi"
    nonisolated static let currentVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 14400, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.check()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func check() {
        let urlStr =
            "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                return
            }
            guard !release.prerelease, !release.draft else { return }

            let remoteVersion =
                release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst()) : release.tag_name
            if Self.isNewer(remote: remoteVersion, current: Self.currentVersion) {
                Task { @MainActor [weak self] in
                    self?.appState?.updateAvailable = (
                        version: remoteVersion, url: release.html_url
                    )
                }
            }
        }.resume()
    }

    nonisolated static func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }
}

// MARK: - Launch at Login

struct LaunchAtLoginManager {
    @available(macOS 13.0, *)
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }

    @available(macOS 13.0, *)
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
