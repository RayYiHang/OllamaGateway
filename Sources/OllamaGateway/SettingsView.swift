import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) var theme

    @State private var ollamaURL: String = ""
    @State private var portString: String = ""
    @State private var newKeyInput: String = ""
    @State private var showSaved = false
    @State private var copiedKeyId: String?
    @State private var revealedKeys: Set<String> = []
    @State private var showPortInfo = false

    @State private var copiedTunnelURL = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                serverConfigSection
                apiKeysSection
                tunnelSection
                appearanceSection
                generalSection
                aboutSection
            }
            .padding(20)
        }
        .background(
            theme.background.opacity(0.6)
                .background(.ultraThinMaterial)
        )
        .onAppear {
            ollamaURL = appState.config.ollamaBaseURL
            portString = "\(appState.config.port)"
        }
    }

    // MARK: - Server Config

    private var serverConfigSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(L10n.serverConfig)

            VStack(spacing: 12) {
                // Ollama URL
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.ollamaBaseURL)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondaryText)

                    TextField("http://localhost:11434", text: $ollamaURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(theme.primaryText)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.cardBorder.opacity(0.5), lineWidth: 1)
                                )
                        )
                }

                // Port
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(L10n.serverPort)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.secondaryText)

                        Button(action: { showPortInfo.toggle() }) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.warning)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showPortInfo, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.portInfoTitle)
                                    .font(.system(size: 12, weight: .bold))
                                Text(L10n.portInfoDesc)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(width: 260)
                        }
                    }

                    TextField("8000", text: $portString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(theme.primaryText)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.cardBorder.opacity(0.5), lineWidth: 1)
                                )
                        )
                }

                // Save button
                HStack {
                    Spacer()
                    Button(action: saveConfig) {
                        HStack(spacing: 6) {
                            Image(systemName: showSaved ? "checkmark" : "square.and.arrow.down")
                                .font(.system(size: 11))
                            Text(showSaved ? L10n.saved : L10n.saveApply)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(showSaved ? theme.success : theme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - API Keys

    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(L10n.apiKeysTitle)

            VStack(spacing: 12) {
                // Add key input
                HStack(spacing: 8) {
                    TextField("sk-your-api-key", text: $newKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.primaryText)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.cardBorder.opacity(0.5), lineWidth: 1)
                                )
                        )

                    Button(action: addKey) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(newKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Generate random key
                Button(action: generateRandomKey) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text(L10n.generateKey)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(theme.accent)
                }
                .buttonStyle(.plain)

                Divider().opacity(0.3)

                // Key list
                if appState.config.apiKeys.isEmpty {
                    HStack {
                        Spacer()
                        Text(L10n.noKeys)
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                            .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    ForEach(appState.config.apiKeys, id: \.self) { key in
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                                .foregroundColor(theme.accent.opacity(0.7))

                            Text(revealedKeys.contains(key) ? key : maskKey(key))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(theme.primaryText)
                                .lineLimit(1)
                                .textSelection(.enabled)

                            Spacer()

                            // Reveal / Hide
                            Button(action: {
                                if revealedKeys.contains(key) {
                                    revealedKeys.remove(key)
                                } else {
                                    revealedKeys.insert(key)
                                }
                            }) {
                                Image(systemName: revealedKeys.contains(key) ? "eye.slash" : "eye")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.secondaryText)
                            }
                            .buttonStyle(.plain)

                            // Copy
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(key, forType: .string)
                                copiedKeyId = key
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    if copiedKeyId == key { copiedKeyId = nil }
                                }
                            }) {
                                Text(copiedKeyId == key ? L10n.copied : L10n.copyKey)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(
                                        copiedKeyId == key ? theme.success : theme.secondaryText)
                            }
                            .buttonStyle(.plain)

                            // Delete
                            Button(action: { deleteKey(key) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.error.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - Cloudflare Tunnel

    private var tunnelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(L10n.tunnelTitle)

            VStack(spacing: 12) {
                // Status row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tunnelStatus)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryText)
                        Text(tunnelStatusLabel)
                            .font(.system(size: 11))
                            .foregroundColor(tunnelStatusColor)
                    }
                    Spacer()

                    // Start / Stop button
                    Button(action: toggleTunnel) {
                        HStack(spacing: 6) {
                            if appState.tunnelStatus.isBusy {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(
                                    systemName: appState.tunnelStatus.isRunning
                                        ? "stop.fill" : "play.fill"
                                )
                                .font(.system(size: 10))
                            }
                            Text(appState.tunnelStatus.isRunning ? L10n.stop : L10n.start)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    appState.tunnelStatus.isRunning
                                        ? theme.error : theme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.tunnelStatus.isBusy)
                }

                // Public URL display
                if let url = appState.tunnelStatus.publicURL {
                    Divider().opacity(0.3)
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accent)
                        Text(url)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(theme.primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                            copiedTunnelURL = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedTunnelURL = false
                            }
                        }) {
                            Text(copiedTunnelURL ? L10n.copied : L10n.copyKey)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(
                                    copiedTunnelURL ? theme.success : theme.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.accent.opacity(0.06))
                    )
                }

                // Downloading indicator
                if case .downloading = appState.tunnelStatus {
                    Divider().opacity(0.3)
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text(L10n.tunnelDownloading)
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }
                }

                // Error message
                if case .error(let msg) = appState.tunnelStatus {
                    Divider().opacity(0.3)
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.error)
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(theme.error)
                            .lineLimit(2)
                    }
                }

                // Info
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)
                    Text(L10n.tunnelInfo)
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    private var tunnelStatusLabel: String {
        switch appState.tunnelStatus {
        case .stopped: return L10n.stopped
        case .downloading: return L10n.tunnelDownloading
        case .starting: return L10n.starting
        case .running: return L10n.tunnelRunning
        case .error: return L10n.errorLabel
        }
    }

    private var tunnelStatusColor: Color {
        switch appState.tunnelStatus {
        case .stopped: return theme.secondaryText
        case .downloading: return theme.warning
        case .starting: return theme.warning
        case .running: return theme.success
        case .error: return theme.error
        }
    }

    private func toggleTunnel() {
        if appState.tunnelStatus.isRunning {
            appState.tunnel?.stop()
        } else {
            // Stop any existing tunnel instance first
            appState.tunnel?.stop()
            let tunnel = CloudflareTunnel(appState: appState)
            appState.tunnel = tunnel
            tunnel.start()
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(L10n.appearance)

            VStack(spacing: 14) {
                // Theme
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.theme)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondaryText)

                    HStack(spacing: 8) {
                        themeButton(.dark, icon: "moon.fill", label: L10n.darkMode)
                        themeButton(.light, icon: "sun.max.fill", label: L10n.lightMode)
                        themeButton(.system, icon: "circle.lefthalf.filled", label: L10n.systemMode)
                    }
                }

                Divider().opacity(0.3)

                // Language
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondaryText)

                    HStack(spacing: 8) {
                        langButton(.zh, label: "中文")
                        langButton(.en, label: "English")
                    }
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(L10n.general)

            VStack(spacing: 12) {
                // Launch at login
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.launchAtLogin)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $appState.launchAtLogin)
                        .toggleStyle(.switch)
                        .scaleEffect(0.75)
                        .onChange(of: appState.launchAtLogin) { newValue in
                            LaunchAtLoginManager.setEnabled(newValue)
                        }
                }

                Divider().opacity(0.3)

                // Check for updates
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.checkUpdate)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                    Spacer()
                    Button(action: {
                        appState.updateChecker?.check()
                    }) {
                        Text(L10n.checkUpdate)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.accent.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if let update = appState.updateAvailable {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(theme.accent)
                        Text("\(L10n.updateAvailable): v\(update.version)")
                            .font(.system(size: 12))
                            .foregroundColor(theme.primaryText)
                        Spacer()
                        Button(action: {
                            if let url = URL(string: update.url) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text(L10n.download)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(theme.accent))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.accent.opacity(0.08))
                    )
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(L10n.about)

            HStack(spacing: 12) {
                AppIconView(size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ollama Gateway")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    Text("\(L10n.version) \(UpdateChecker.currentVersion)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                    Text("MIT License")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText.opacity(0.7))
                }

                Spacer()
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - Button Helpers

    private func themeButton(_ mode: ThemeMode, icon: String, label: String) -> some View {
        Button(action: { appState.themeMode = mode }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(appState.themeMode == mode ? .white : theme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(appState.themeMode == mode ? theme.accent : theme.background)
            )
        }
        .buttonStyle(.plain)
    }

    private func langButton(_ lang: AppLanguage, label: String) -> some View {
        Button(action: {
            appState.language = lang
            L10n.lang = lang
        }) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(appState.language == lang ? .white : theme.secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(appState.language == lang ? theme.accent : theme.background)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func saveConfig() {
        appState.config.ollamaBaseURL = ollamaURL.trimmingCharacters(in: .whitespaces)
        if let p = UInt16(portString) { appState.config.port = p }
        appState.saveConfig()
        appState.proxyServer?.updateConfig(appState.config)

        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaved = false
        }
    }

    private func addKey() {
        let key = newKeyInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !appState.config.apiKeys.contains(key) else { return }
        appState.config.apiKeys.append(key)
        appState.saveConfig()
        newKeyInput = ""
    }

    private func generateRandomKey() {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let random = String((0..<32).map { _ in chars.randomElement()! })
        let key = "sk-\(random)"
        appState.config.apiKeys.append(key)
        appState.saveConfig()
    }

    private func deleteKey(_ key: String) {
        appState.config.apiKeys.removeAll { $0 == key }
        appState.saveConfig()
    }

    private func maskKey(_ key: String) -> String {
        if key.count <= 8 { return key }
        let prefix = String(key.prefix(6))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••\(suffix)"
    }
}
