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

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                serverConfigSection
                apiKeysSection
                appearanceSection
                generalSection
                aboutSection
            }
            .padding(20)
        }
        .background(theme.background)
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
                    Text(L10n.serverPort)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondaryText)

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

                            Text(maskKey(key))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(theme.primaryText)
                                .lineLimit(1)

                            Spacer()

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
                                    .foregroundColor(copiedKeyId == key ? theme.success : theme.secondaryText)
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

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(L10n.about)

            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.accentGradient)

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
