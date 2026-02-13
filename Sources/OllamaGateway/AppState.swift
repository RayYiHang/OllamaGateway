import Foundation

// MARK: - Server Configuration

struct ServerConfig: Codable, Equatable {
    var ollamaBaseURL: String
    var port: UInt16
    var apiKeys: [String]

    static let `default` = ServerConfig(
        ollamaBaseURL: "http://localhost:11434",
        port: 8000,
        apiKeys: []
    )
}

// MARK: - Request Log Entry

struct RequestLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let path: String
    let statusCode: Int
    let latencyMs: Double
    let clientIP: String

    var isSuccess: Bool { (200..<400).contains(statusCode) }
}

// MARK: - Server Status

enum ServerStatus: Equatable {
    case stopped
    case starting
    case running
    case error(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .stopped: return "stopped"
        case .starting: return "starting"
        case .running: return "running"
        case .error: return "error"
        }
    }
}

// MARK: - Ollama Status

enum OllamaStatus: Equatable {
    case unknown
    case online
    case offline

    var label: String {
        switch self {
        case .unknown: return "unknown"
        case .online: return "online"
        case .offline: return "offline"
        }
    }
}

// MARK: - Dashboard Stats

struct DashboardStats {
    var totalRequests: Int = 0
    var successRequests: Int = 0
    var errorRequests: Int = 0
    var avgLatencyMs: Double = 0
    var requestsPerMinute: [Int] = Array(repeating: 0, count: 60)
    var uptimeSeconds: TimeInterval = 0
    private var lastRecordedHour: Int = -1

    var successRate: Double {
        guard totalRequests > 0 else { return 100 }
        return Double(successRequests) / Double(totalRequests) * 100
    }

    mutating func record(_ entry: RequestLogEntry) {
        totalRequests += 1
        if entry.isSuccess {
            successRequests += 1
        } else {
            errorRequests += 1
        }
        let total = Double(totalRequests)
        avgLatencyMs = avgLatencyMs * (total - 1) / total + entry.latencyMs / total

        let currentHour = Calendar.current.component(.hour, from: entry.timestamp)
        if currentHour != lastRecordedHour {
            requestsPerMinute = Array(repeating: 0, count: 60)
            lastRecordedHour = currentHour
        }

        let minuteIndex = Calendar.current.component(.minute, from: entry.timestamp)
        if minuteIndex < requestsPerMinute.count {
            requestsPerMinute[minuteIndex] += 1
        }
    }

    mutating func reset() {
        totalRequests = 0
        successRequests = 0
        errorRequests = 0
        avgLatencyMs = 0
        requestsPerMinute = Array(repeating: 0, count: 60)
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    // Server
    @Published var serverStatus: ServerStatus = .stopped
    @Published var ollamaStatus: OllamaStatus = .unknown
    @Published var config: ServerConfig
    @Published var stats = DashboardStats()
    @Published var requestLogs: [RequestLogEntry] = []
    @Published var serverStartTime: Date?

    // UI
    @Published var selectedTab: AppTab = .dashboard
    @Published var showMainWindow = true

    // Preferences (persisted)
    @Published var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode") }
    }
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    // Update
    @Published var updateAvailable: (version: String, url: String)?

    // Services
    var proxyServer: ProxyServer?
    var healthChecker: HealthChecker?
    var updateChecker: UpdateChecker?

    static let maxLogEntries = 200

    init() {
        // Load persisted config
        let ollamaURL = UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"
        let port = UInt16(UserDefaults.standard.integer(forKey: "serverPort"))
        let keysStr = UserDefaults.standard.string(forKey: "apiKeys") ?? ""
        let keys = keysStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        self.config = ServerConfig(
            ollamaBaseURL: ollamaURL,
            port: port > 0 ? port : 8000,
            apiKeys: keys
        )

        self.themeMode = ThemeMode(rawValue: UserDefaults.standard.string(forKey: "themeMode") ?? "") ?? .dark
        self.language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .zh
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    func saveConfig() {
        UserDefaults.standard.set(config.ollamaBaseURL, forKey: "ollamaBaseURL")
        UserDefaults.standard.set(Int(config.port), forKey: "serverPort")
        UserDefaults.standard.set(config.apiKeys.joined(separator: ","), forKey: "apiKeys")
    }

    func addLogEntry(_ entry: RequestLogEntry) {
        requestLogs.insert(entry, at: 0)
        if requestLogs.count > Self.maxLogEntries {
            requestLogs.removeLast()
        }
        stats.record(entry)
    }

    func clearLogs() {
        requestLogs.removeAll()
        stats.reset()
    }
}

// MARK: - Enums

enum AppTab: String, CaseIterable {
    case dashboard
    case settings
}

enum ThemeMode: String, CaseIterable {
    case light, dark, system
}

enum AppLanguage: String, CaseIterable {
    case zh, en
}
