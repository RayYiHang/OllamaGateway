import AppKit
import SwiftUI

// MARK: - App Entry

@main
struct OllamaGatewayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .preferredColorScheme(appState.themeMode.colorScheme())
                .onAppear {
                    setupAppOnce()
                }
        }
        .defaultSize(width: 900, height: 600)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.about) {
                    appState.selectedTab = .settings
                }
            }
        }
    }

    private func setupAppOnce() {
        guard appState.healthChecker == nil else { return }

        L10n.lang = appState.language
        delegate.appState = appState
        delegate.setupStatusBar()

        let healthChecker = HealthChecker(appState: appState)
        healthChecker.start()
        appState.healthChecker = healthChecker

        let updateChecker = UpdateChecker(appState: appState)
        updateChecker.start()
        appState.updateChecker = updateChecker

        // Auto-start Cloudflare Tunnel if enabled
        if appState.autoStartTunnel {
            let tunnel = CloudflareTunnel(appState: appState)
            appState.tunnel = tunnel
            tunnel.start()
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var menuUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hide = UserDefaults.standard.bool(forKey: "hideDockIcon")
        NSApp.setActivationPolicy(hide ? .accessory : .regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window is closed; keep running in menu bar
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
        -> Bool
    {
        if !flag {
            // Reopen main window when clicking Dock icon
            for window in NSApp.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(self)
                    break
                }
            }
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.tunnel?.stop()
        appState?.proxyServer?.stop()
        appState?.healthChecker?.stop()
        appState?.updateChecker?.stop()
    }

    // MARK: - Status Bar

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Try to load custom status bar icon (.icns)
            if let iconPath = Bundle.main.path(forResource: "StatusBarIcon", ofType: "icns"),
                let image = NSImage(contentsOfFile: iconPath)
            {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                // Fallback to SF Symbol
                button.image = NSImage(
                    systemSymbolName: "server.rack", accessibilityDescription: "Ollama Gateway")
                button.image?.size = NSSize(width: 18, height: 18)
                button.image?.isTemplate = true
            }
            button.action = #selector(statusBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateStatusMenu()

        menuUpdateTimer?.invalidate()
        menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusMenu()
            }
        }
    }

    private func updateStatusMenu() {
        let menu = NSMenu()

        // Status indicator
        let gwLabel =
            appState?.serverStatus.isRunning == true
            ? "Ollama Gateway: \(L10n.running)" : "Ollama Gateway: \(L10n.stopped)"
        let statusIcon = appState?.serverStatus.isRunning == true ? "🟢" : "🔴"
        let statusItem = NSMenuItem(
            title: "\(statusIcon) \(gwLabel)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // Ollama status
        let ollamaIcon = appState?.ollamaStatus == .online ? "🟢" : "🔴"
        let ollamaLabel = appState?.ollamaStatus == .online ? L10n.online : L10n.offline
        let ollamaItem = NSMenuItem(
            title: "Ollama: \(ollamaIcon) \(ollamaLabel)", action: nil, keyEquivalent: "")
        ollamaItem.isEnabled = false
        menu.addItem(ollamaItem)

        menu.addItem(NSMenuItem.separator())

        // Start / Stop
        if appState?.serverStatus.isRunning == true {
            let stopItem = NSMenuItem(
                title: L10n.stopServer, action: #selector(stopServer), keyEquivalent: "s")
            stopItem.target = self
            menu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(
                title: L10n.startServer, action: #selector(startServer), keyEquivalent: "s")
            startItem.target = self
            menu.addItem(startItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Show Window
        let showItem = NSMenuItem(
            title: L10n.showWindow, action: #selector(showMainWindow), keyEquivalent: "o")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusMenu = menu
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // Right-click: show menu
            updateStatusMenu()
            self.statusItem?.menu = statusMenu
            self.statusItem?.button?.performClick(nil)
            // Reset menu to nil so action fires next time
            DispatchQueue.main.async { [weak self] in
                self?.statusItem?.menu = nil
            }
        } else {
            // Left-click: toggle main window
            showMainWindow()
        }
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }

    @objc private func startServer() {
        Task { @MainActor [weak self] in
            guard let appState = self?.appState else { return }
            guard !appState.config.apiKeys.isEmpty else {
                self?.showMainWindow()
                appState.selectedTab = .settings
                return
            }

            let server = ProxyServer(config: appState.config)
            server.onStateChange = { [weak appState] status in
                Task { @MainActor [weak appState] in
                    appState?.serverStatus = status
                    if status.isRunning {
                        appState?.serverStartTime = Date()
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
            self?.updateStatusMenu()
        }
    }

    @objc private func stopServer() {
        Task { @MainActor [weak self] in
            self?.appState?.proxyServer?.stop()
            self?.appState?.serverStartTime = nil
            self?.updateStatusMenu()
        }
    }

    @objc private func quitApp() {
        // Cleanup handled in applicationWillTerminate
        NSApp.terminate(nil)
    }
}
