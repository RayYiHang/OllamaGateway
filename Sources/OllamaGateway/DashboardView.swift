import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) var theme

    var healthScore: Int {
        var score = 50
        if appState.ollamaStatus == .online { score += 25 }
        if appState.serverStatus.isRunning { score += 15 }
        if appState.stats.successRate > 95 {
            score += 10
        } else if appState.stats.successRate > 80 {
            score += 5
        }
        return min(score, 100)
    }

    var uptimeLabel: String {
        appState.stats.uptimeSeconds.uptimeString
    }

    var stabilityLabel: String {
        if appState.stats.successRate >= 95 { return L10n.good }
        if appState.stats.successRate >= 80 { return L10n.average }
        return L10n.poor
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                detailCardsGrid
                activitySection
                requestLogSection
            }
            .padding(20)
        }
        .background(theme.background)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.serverHealth)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                HStack(spacing: 8) {
                    Text(appState.serverStatus.isRunning ? L10n.running : L10n.stopped)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(
                            appState.serverStatus.isRunning ? theme.accent : theme.secondaryText)
                }

                Text("\(L10n.details):")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            ScoreCircle(score: healthScore, size: 56)
        }
    }

    // MARK: - Detail Cards Grid

    private var detailCardsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12
        ) {
            DetailCard(
                title: L10n.duration,
                value: uptimeLabel,
                icon: "clock.fill",
                iconColor: theme.accent,
                statusDot: theme.success
            )

            DetailCard(
                title: L10n.averageLatency,
                value: appState.stats.avgLatencyMs.latencyString,
                icon: "bolt.fill",
                iconColor: theme.warning,
                statusDot: appState.stats.avgLatencyMs < 200 ? theme.success : theme.warning
            )

            DetailCard(
                title: L10n.regularity,
                value: stabilityLabel,
                icon: "waveform.path.ecg",
                iconColor: Color(r: 106, g: 90, b: 205),
                statusDot: appState.stats.successRate >= 95 ? theme.success : theme.warning
            )

            DetailCard(
                title: L10n.interruptions,
                value: "\(appState.stats.errorRequests)" + L10n.times,
                icon: "exclamationmark.triangle.fill",
                iconColor: appState.stats.errorRequests == 0 ? theme.success : theme.warning,
                statusDot: appState.stats.errorRequests == 0 ? theme.success : theme.warning
            )
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(L10n.requestActivity)

            // Activity bar chart
            GeometryReader { geo in
                let data = appState.stats.requestsPerMinute
                let maxVal = max(data.max() ?? 1, 1)
                let barWidth = max(
                    (geo.size.width - CGFloat(data.count) * 1.5) / CGFloat(data.count), 2)

                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(data.indices, id: \.self) { i in
                        let h =
                            data[i] > 0
                            ? max(CGFloat(data[i]) / CGFloat(maxVal) * geo.size.height, 3) : 1
                        let isCurrentMinute = i == Calendar.current.component(.minute, from: Date())

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                data[i] > 0
                                    ? (isCurrentMinute ? theme.accent : Color(r: 0, g: 150, b: 220))
                                    : theme.cardBorder.opacity(0.15)
                            )
                            .frame(width: barWidth, height: h)
                    }
                }
            }
            .frame(height: 80)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.cardBorder.opacity(0.5), lineWidth: 0.5)
                    )
            )

            // Time labels
            HStack {
                Text(startTimeLabel())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.secondaryText)
                Spacer()
                Text(currentTimeLabel())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.secondaryText)
            }
        }
    }

    // MARK: - Request Log

    private var requestLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                L10n.recentRequests,
                action: {
                    appState.clearLogs()
                }, actionLabel: L10n.clearLogs)

            if appState.requestLogs.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundColor(theme.secondaryText.opacity(0.5))
                        Text(L10n.noRequests)
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.cardBackground)
                )
            } else {
                VStack(spacing: 0) {
                    // Table Header
                    HStack(spacing: 0) {
                        Text(L10n.method)
                            .frame(width: 60, alignment: .leading)
                        Text(L10n.path)
                            .frame(minWidth: 150, alignment: .leading)
                        Spacer()
                        Text(L10n.status)
                            .frame(width: 50, alignment: .center)
                        Text(L10n.latency)
                            .frame(width: 70, alignment: .trailing)
                        Text(L10n.time)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    Divider().opacity(0.3)

                    // Rows
                    ForEach(appState.requestLogs.prefix(20)) { log in
                        requestRow(log)
                        if log.id != appState.requestLogs.prefix(20).last?.id {
                            Divider().opacity(0.15)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.cardBorder.opacity(0.5), lineWidth: 0.5)
                        )
                )
            }
        }
    }

    private func requestRow(_ log: RequestLogEntry) -> some View {
        HStack(spacing: 0) {
            Text(log.method)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(methodColor(log.method))
                .frame(width: 60, alignment: .leading)

            Text(log.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 150, alignment: .leading)

            Spacer()

            Text("\(log.statusCode)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(log.isSuccess ? theme.success : theme.error)
                .frame(width: 50, alignment: .center)

            Text(log.latencyMs.latencyString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.secondaryText)
                .frame(width: 70, alignment: .trailing)

            Text(timeFormatter(log.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.secondaryText)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return Color(r: 0, g: 180, b: 216)
        case "POST": return theme.accent
        case "PUT": return theme.warning
        case "DELETE": return theme.error
        default: return theme.secondaryText
        }
    }

    // MARK: - Cached Formatters

    private static let timeFormatterHMS: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let timeFormatterHM: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func timeFormatter(_ date: Date) -> String {
        Self.timeFormatterHMS.string(from: date)
    }

    private func startTimeLabel() -> String {
        if let start = appState.serverStartTime {
            return Self.timeFormatterHM.string(from: start)
        }
        return "--:--"
    }

    private func currentTimeLabel() -> String {
        Self.timeFormatterHM.string(from: Date())
    }
}
