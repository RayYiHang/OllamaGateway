# Ollama Gateway — Plan & Spec

## 1. 项目概述

为本地 Ollama 提供 **原生 macOS GUI 应用** + API Key 鉴权反向代理网关。

```
Client (公网/本地)
  │
  ▼
┌─────────────────────────────────┐
│  Ollama Gateway (macOS App)     │
│  ┌───────────────────────────┐  │
│  │  SwiftUI GUI              │  │
│  │  • Dashboard 仪表盘       │  │
│  │  • 设置管理               │  │
│  │  • 状态栏控制             │  │
│  └───────────┬───────────────┘  │
│  ┌───────────▼───────────────┐  │
│  │  HTTP Proxy Server (:8000)│  │
│  │  • API Key 鉴权           │  │
│  │  • 透明反向代理           │  │
│  │  • 流式响应支持           │  │
│  └───────────┬───────────────┘  │
└──────────────┼──────────────────┘
               ▼
         Ollama (:11434)
```

**双部署模式**：
- 🖥️ **macOS 原生应用** — 零依赖 GUI，适合桌面用户
- 🐳 **Docker 部署** — Python FastAPI，适合服务器部署

## 2. 架构设计

### 2.1 核心决策

| 决策 | 方案 | 理由 |
|------|------|------|
| GUI 框架 | SwiftUI | macOS 原生、现代声明式 UI |
| HTTP 服务器 | `NWListener` (Network.framework) | 零外部依赖、系统框架 |
| HTTP 客户端 | `URLSession` | 原生流式传输 |
| 自动更新 | GitHub API + 内置更新器 | 无第三方框架 |
| 开机自启 | `SMAppService` (macOS 13+) | 官方 API |
| 持久化 | `@AppStorage` / `UserDefaults` | 轻量级 |
| 本地化 | 代码内枚举 | 无资源文件依赖 |
| 构建工具 | Swift Package Manager | 无需 .xcodeproj |
| 外部依赖 | **零** | 最小二进制体积 |

### 2.2 数据流

```
Client → NWListener (TCP) → HTTP Parser → API Key 验证
  → URLSession → Ollama → 流式响应 → Client
  → RequestLog → Dashboard UI 更新
```

## 3. 功能矩阵

| 功能 | 描述 | 状态 |
|------|------|------|
| HTTP 反向代理 | Bearer Token 鉴权 + 透明代理 | ✅ |
| 启停控制 | GUI + 状态栏一键控制 | ✅ |
| Ollama 健康检测 | 实时连接状态监控 | ✅ |
| API Key 管理 | 增删查看 | ✅ |
| 请求 Dashboard | 统计、延迟、成功率、活动图 | ✅ |
| 请求日志 | 实时日志列表 | ✅ |
| 状态栏菜单 | 快捷控制 + 状态指示 | ✅ |
| Dock 图标 | 自定义图标 | ✅ |
| 明暗主题 | 日间/夜间/跟随系统 | ✅ |
| 中英文切换 | 默认中文 | ✅ |
| 开机自启 | SMAppService | ✅ |
| 自动更新 | GitHub Release 检测 | ✅ |
| DMG 打包 | 一键构建分发包 | ✅ |
| GitHub Actions | 自动构建 x86+ARM Universal Binary | ✅ |

## 4. UI 设计规范

### 设计风格
- 灵感来源：Withings Health Dashboard
- 暗色主题为主 (#0D1117)，青绿强调色 (#00D4AA)
- 圆角卡片布局，左侧边栏 + 右侧内容区
- 900×600 默认窗口大小

### 色彩体系

| 元素 | 暗色 | 亮色 |
|------|------|------|
| 背景 | `#0D1117` | `#F6F8FA` |
| 卡片 | `#161B22` | `#FFFFFF` |
| 边框 | `#30363D` | `#D0D7DE` |
| 强调 | `#00D4AA` | `#00B894` |

## 5. 项目结构

```
ollamafastapi/
├── Package.swift                    # SPM（零依赖）
├── Sources/OllamaGateway/
│   ├── OllamaGatewayApp.swift       # 入口 + AppDelegate + StatusBar
│   ├── AppState.swift               # 数据模型 + 应用状态
│   ├── ProxyServer.swift            # HTTP 反向代理
│   ├── Services.swift               # 健康检测 + 更新 + 自启
│   ├── Theme.swift                  # 主题系统
│   ├── Localization.swift           # 本地化
│   ├── MainView.swift               # 主窗口
│   ├── DashboardView.swift          # 仪表盘
│   ├── SettingsView.swift           # 设置
│   └── Components.swift             # UI 组件
├── scripts/                         # 构建脚本
├── .github/workflows/release.yml    # CI/CD
├── main.py + Dockerfile             # Docker 部署
└── docs/PLAN.md
```

## 6. API 行为

- `GET /` — 健康检查（无需鉴权）
- `/{path:path}` — 透明代理到 Ollama（需 Bearer Token）

## 7. 非目标

- 不替代 Docker 部署（Python 版本保留）
- 不做 Windows/Linux 版本
- 不做限流（可由 Cloudflare 处理）
- 不做用户权限管理系统
