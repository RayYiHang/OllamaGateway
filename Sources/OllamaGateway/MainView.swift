import SwiftUI

// MARK: - Main View

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var systemScheme
    @State private var uptimeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var theme: AppTheme {
        appState.themeMode.resolvedTheme(systemScheme: systemScheme)
    }

    var body: some View {
        HSplitView {
            sidebarView
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)

            contentView
                .frame(minWidth: 500)
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(theme.background)
        .environment(\.theme, theme)
        .onReceive(uptimeTimer) { _ in
            updateUptime()
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.accentGradient)

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.appName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    Text(L10n.overview)
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.3)

            // Stat Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // Requests Card
                    StatCard(
                        title: L10n.todayRequests,
                        value: "\(appState.stats.totalRequests)",
                        subtitle: String(format: "%.0f%%", appState.stats.successRate),
                        trailing: timeStr()
                    ) {
                        MiniBarChart(
                            data: Array(appState.stats.requestsPerMinute.suffix(20)),
                            barColor: theme.accent
                        )
                        .frame(height: 30)
                    }

                    // Ollama Status
                    StatCard(
                        title: L10n.ollamaStatus,
                        value: appState.ollamaStatus == .online ? L10n.online : L10n.offline,
                        icon: appState.ollamaStatus == .online
                            ? "checkmark.circle.fill" : "xmark.circle.fill",
                        iconColor: appState.ollamaStatus == .online ? theme.success : theme.error
                    ) {
                        HealthBadge(status: appState.ollamaStatus)
                    }

                    // Server Status
                    StatCard(
                        title: L10n.server,
                        value: appState.serverStatus.isRunning ? L10n.running : L10n.stopped,
                        subtitle: ":\(appState.config.port)"
                    ) {
                        ServerStatusBadge(status: appState.serverStatus)
                    }

                    // API Keys
                    StatCard(
                        title: L10n.apiKeys,
                        value: "\(appState.config.apiKeys.count)",
                        icon: "key.fill",
                        iconColor: theme.accent
                    )

                    // Latency
                    StatCard(
                        title: L10n.latency,
                        value: appState.stats.avgLatencyMs.latencyString,
                        icon: "bolt.fill",
                        iconColor: theme.warning
                    )

                    // Errors
                    if appState.stats.errorRequests > 0 {
                        StatCard(
                            title: L10n.errors,
                            value: "\(appState.stats.errorRequests)",
                            icon: "exclamationmark.triangle.fill",
                            iconColor: theme.error
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            Spacer(minLength: 0)

            // Bottom Controls
            bottomBar
        }
        .background(theme.sidebarBackground)
    }

    // MARK: - Content Area

    private var contentView: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 0) {
                tabButton(.dashboard, icon: "chart.bar.fill", label: L10n.dashboard)
                tabButton(.settings, icon: "gearshape.fill", label: L10n.settings)
                Spacer()

                // Theme Toggle
                Button(action: { toggleTheme() }) {
                    Image(
                        systemName: appState.themeMode == .dark
                            ? "moon.fill"
                            : (appState.themeMode == .light
                                ? "sun.max.fill" : "circle.lefthalf.filled")
                    )
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Language Toggle
                Button(action: { toggleLanguage() }) {
                    Text(appState.language == .zh ? "EN" : "中")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.secondaryText)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.cardBackground.opacity(0.5))

            Divider().opacity(0.3)

            // Content
            Group {
                switch appState.selectedTab {
                case .dashboard:
                    DashboardView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: AppTab, icon: String, label: String) -> some View {
        Button(action: { appState.selectedTab = tab }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(appState.selectedTab == tab ? theme.accent : theme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(appState.selectedTab == tab ? theme.accent.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Divider().opacity(0.3)

            HStack(spacing: 10) {
                Button(action: { toggleServer() }) {
                    HStack(spacing: 6) {
                        Image(
                            systemName: appState.serverStatus.isRunning ? "stop.fill" : "play.fill"
                        )
                        .font(.system(size: 11))
                        Text(appState.serverStatus.isRunning ? L10n.stop : L10n.start)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(appState.serverStatus.isRunning ? theme.error : theme.accent)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(L10n.port): \(appState.config.port)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    private func toggleServer() {
        if appState.serverStatus.isRunning {
            appState.proxyServer?.stop()
        } else {
            startServer()
        }
    }

    private func startServer() {
        guard !appState.config.apiKeys.isEmpty else {
            appState.selectedTab = .settings
            return
        }
        let server = ProxyServer(config: appState.config)
        server.onStateChange = { [weak appState] status in
            Task { @MainActor [weak appState] in
                appState?.serverStatus = status
                if status.isRunning {
                    appState?.serverStartTime = Date()
                } else {
                    appState?.serverStartTime = nil
                }
            }
        }
        server.onRequestLog = { [weak appState] entry in
            Task { @MainActor [weak appState] in
                appState?.addLogEntry(entry)
            }
        }
        appState.proxyServer = server
        do {
            try server.start()
        } catch {
            appState.serverStatus = .error(error.localizedDescription)
        }
    }

    private func toggleTheme() {
        switch appState.themeMode {
        case .dark: appState.themeMode = .light
        case .light: appState.themeMode = .system
        case .system: appState.themeMode = .dark
        }
    }

    private func toggleLanguage() {
        appState.language = appState.language == .zh ? .en : .zh
        L10n.lang = appState.language
    }

    private func updateUptime() {
        if let start = appState.serverStartTime {
            appState.stats.uptimeSeconds = Date().timeIntervalSince(start)
        }
    }

    private static let hmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func timeStr() -> String {
        Self.hmFormatter.string(from: Date())
    }
}
