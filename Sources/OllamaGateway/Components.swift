import SwiftUI

// MARK: - Stat Card

struct StatCard<Content: View>: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color?
    let trailing: String?
    let content: (() -> Content)?

    @Environment(\.theme) var theme

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        trailing: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondaryText)
                Spacer()
                if let trailing = trailing {
                    Text(trailing)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.secondaryText.opacity(0.7))
                }
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor ?? theme.accent)
                }
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primaryText)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                        .padding(.bottom, 4)
                }
            }

            if let content = content {
                content()
            }
        }
        .padding(14)
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

extension StatCard where Content == EmptyView {
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        trailing: String? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = trailing
        self.content = nil
    }
}

// MARK: - Health Badge

struct HealthBadge: View {
    let status: OllamaStatus
    @Environment(\.theme) var theme

    var color: Color {
        switch status {
        case .online: return theme.success
        case .offline: return theme.error
        case .unknown: return theme.warning
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(status == .online ? L10n.online : (status == .offline ? L10n.offline : "..."))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
    }
}

// MARK: - Server Status Badge

struct ServerStatusBadge: View {
    let status: ServerStatus
    @Environment(\.theme) var theme

    var color: Color {
        switch status {
        case .running: return theme.success
        case .stopped: return theme.secondaryText
        case .starting: return theme.warning
        case .error: return theme.error
        }
    }

    var label: String {
        switch status {
        case .running: return L10n.running
        case .stopped: return L10n.stopped
        case .starting: return L10n.starting
        case .error: return L10n.errorLabel
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
    }
}

// MARK: - Mini Bar Chart

struct MiniBarChart: View {
    let data: [Int]
    let barColor: Color

    @Environment(\.theme) var theme

    var body: some View {
        GeometryReader { geo in
            let maxVal = max(data.max() ?? 1, 1)
            let barWidth = max(
                (geo.size.width - CGFloat(data.count - 1) * 2) / CGFloat(data.count), 2)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(data.indices, id: \.self) { i in
                    let h =
                        data[i] > 0
                        ? max(CGFloat(data[i]) / CGFloat(maxVal) * geo.size.height, 2) : 2
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(data[i] > 0 ? barColor : theme.cardBorder.opacity(0.3))
                        .frame(width: barWidth, height: h)
                }
            }
        }
    }
}

// MARK: - Score Circle

struct ScoreCircle: View {
    let score: Int
    let size: CGFloat
    @Environment(\.theme) var theme

    var color: Color {
        if score >= 80 { return theme.accent }
        if score >= 60 { return theme.warning }
        return theme.error
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.cardBorder.opacity(0.3), lineWidth: 4)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

// MARK: - Detail Card (Withings Style)

struct DetailCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    let statusDot: Color?

    @Environment(\.theme) var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(theme.secondaryText.opacity(0.5))
                }

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primaryText)

                if let dot = statusDot {
                    Circle()
                        .fill(dot)
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(iconColor)
                )
        }
        .padding(14)
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

// MARK: - Toolbar Button

struct ToolbarIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundColor(theme.secondaryText)
            .frame(width: 44, height: 36)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let action: (() -> Void)?
    let actionLabel: String?

    @Environment(\.theme) var theme

    init(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        self.title = title
        self.action = action
        self.actionLabel = actionLabel
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryText)
            Spacer()
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
