import Foundation

// MARK: - Localization

enum L10n {
    static var lang: AppLanguage = .zh

    // App
    static var appName: String { s("Ollama 网关", "Ollama Gateway") }

    // Tabs
    static var dashboard: String { s("仪表盘", "Dashboard") }
    static var settings: String { s("设置", "Settings") }

    // Sidebar
    static var overview: String { s("概览", "Overview") }
    static var requests: String { s("请求", "Requests") }
    static var todayRequests: String { s("今日请求", "Today's Requests") }
    static var ollamaStatus: String { s("Ollama 状态", "Ollama Status") }
    static var server: String { s("服务器", "Server") }
    static var apiKeys: String { s("API 密钥", "API Keys") }
    static var latency: String { s("平均延迟", "Avg Latency") }
    static var errors: String { s("错误", "Errors") }

    // Dashboard
    static var serverHealth: String { s("服务健康", "Server Health") }
    static var uptime: String { s("运行时间", "Uptime") }
    static var avgLatency: String { s("平均延迟", "Avg Latency") }
    static var successRate: String { s("成功率", "Success Rate") }
    static var activeModels: String { s("可用模型", "Models") }
    static var requestActivity: String { s("请求活动", "Request Activity") }
    static var recentRequests: String { s("最近请求", "Recent Requests") }
    static var noRequests: String { s("暂无请求记录", "No requests yet") }
    static var online: String { s("在线", "Online") }
    static var offline: String { s("离线", "Offline") }
    static var running: String { s("运行中", "Running") }
    static var stopped: String { s("已停止", "Stopped") }
    static var starting: String { s("启动中", "Starting") }
    static var errorLabel: String { s("错误", "Error") }
    static var clearLogs: String { s("清除日志", "Clear Logs") }
    static var score: String { s("评分", "Score") }
    static var details: String { s("详情", "Details") }
    static var duration: String { s("运行时长", "Duration") }
    static var averageLatency: String { s("平均延迟", "Average Latency") }
    static var regularity: String { s("稳定性", "Regularity") }
    static var interruptions: String { s("中断次数", "Interruptions") }
    static var good: String { s("良好", "Good") }
    static var average: String { s("一般", "Average") }
    static var poor: String { s("较差", "Poor") }
    static var times: String { s("次", " times") }
    static var method: String { s("方法", "Method") }
    static var path: String { s("路径", "Path") }
    static var status: String { s("状态", "Status") }
    static var time: String { s("时间", "Time") }

    // Settings
    static var ollamaBaseURL: String { s("Ollama 地址", "Ollama Base URL") }
    static var serverPort: String { s("监听端口", "Server Port") }
    static var apiKeysTitle: String { s("API 密钥管理", "API Keys Management") }
    static var addKey: String { s("添加密钥", "Add Key") }
    static var generateKey: String { s("生成随机密钥", "Generate Random Key") }
    static var deleteKey: String { s("删除", "Delete") }
    static var noKeys: String { s("尚未配置 API 密钥", "No API keys configured") }
    static var appearance: String { s("外观", "Appearance") }
    static var theme: String { s("主题", "Theme") }
    static var darkMode: String { s("深色", "Dark") }
    static var lightMode: String { s("浅色", "Light") }
    static var systemMode: String { s("跟随系统", "System") }
    static var language: String { s("语言", "Language") }
    static var chinese: String { s("中文", "Chinese") }
    static var english: String { s("英文", "English") }
    static var general: String { s("通用", "General") }
    static var launchAtLogin: String { s("开机自启动", "Launch at Login") }
    static var autoUpdate: String { s("自动检查更新", "Auto Check Updates") }
    static var checkUpdate: String { s("检查更新", "Check for Updates") }
    static var about: String { s("关于", "About") }
    static var version: String { s("版本", "Version") }
    static var saveApply: String { s("保存并应用", "Save & Apply") }
    static var saved: String { s("已保存", "Saved") }
    static var serverConfig: String { s("服务器配置", "Server Configuration") }
    static var copyKey: String { s("复制", "Copy") }
    static var copied: String { s("已复制", "Copied") }

    // Status Bar
    static var showWindow: String { s("显示窗口", "Show Window") }
    static var startServer: String { s("启动服务", "Start Server") }
    static var stopServer: String { s("停止服务", "Stop Server") }
    static var quit: String { s("退出", "Quit") }
    static var serverRunning: String { s("服务运行中", "Server Running") }
    static var serverStopped: String { s("服务已停止", "Server Stopped") }

    // Update
    static var updateAvailable: String { s("发现新版本", "Update Available") }
    static var updateMessage: String {
        s("新版本 %@ 已发布，是否前往下载？", "Version %@ is available. Download now?")
    }
    static var download: String { s("前往下载", "Download") }
    static var later: String { s("稍后", "Later") }
    static var upToDate: String { s("已是最新版本", "Up to date") }

    // Bottom Bar
    static var start: String { s("启动", "Start") }
    static var stop: String { s("停止", "Stop") }
    static var port: String { s("端口", "Port") }

    // MARK: - Helper

    private static func s(_ zh: String, _ en: String) -> String {
        lang == .zh ? zh : en
    }
}

// MARK: - Formatting Helpers

extension TimeInterval {
    var uptimeString: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        if h > 0 {
            return String(format: "%dh%02dm", h, m)
        } else if m > 0 {
            return String(format: "%dm%02ds", m, s)
        } else {
            return "\(s)s"
        }
    }
}

extension Double {
    var latencyString: String {
        if self < 1 {
            return "<1ms"
        } else if self < 1000 {
            return String(format: "%.0fms", self)
        } else {
            return String(format: "%.1fs", self / 1000)
        }
    }
}
