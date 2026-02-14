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

| 决策        | 方案                             | 理由                      |
| ----------- | -------------------------------- | ------------------------- |
| GUI 框架    | SwiftUI                          | macOS 原生、现代声明式 UI |
| HTTP 服务器 | `NWListener` (Network.framework) | 零外部依赖、系统框架      |
| HTTP 客户端 | `URLSession`                     | 原生流式传输              |
| 自动更新    | GitHub API + 内置更新器          | 无第三方框架              |
| 开机自启    | `SMAppService` (macOS 13+)       | 官方 API                  |
| 持久化      | `@AppStorage` / `UserDefaults`   | 轻量级                    |
| 本地化      | 代码内枚举                       | 无资源文件依赖            |
| 构建工具    | Swift Package Manager            | 无需 .xcodeproj           |
| 外部依赖    | **零**                           | 最小二进制体积            |

### 2.2 数据流

```
Client → NWListener (TCP) → HTTP Parser → API Key 验证
  → URLSession → Ollama → 流式响应 → Client
  → RequestLog → Dashboard UI 更新
```

## 3. 功能矩阵

| 功能            | 描述                              | 状态 |
| --------------- | --------------------------------- | ---- |
| HTTP 反向代理   | Bearer Token 鉴权 + 透明代理      | ✅   |
| 启停控制        | GUI + 状态栏一键控制              | ✅   |
| Ollama 健康检测 | 实时连接状态监控                  | ✅   |
| API Key 管理    | 增删查看                          | ✅   |
| 请求 Dashboard  | 统计、延迟、成功率、活动图        | ✅   |
| 请求日志        | 实时日志列表                      | ✅   |
| 状态栏菜单      | 快捷控制 + 状态指示               | ✅   |
| Dock 图标       | 自定义图标                        | ✅   |
| 明暗主题        | 日间/夜间/跟随系统                | ✅   |
| 中英文切换      | 默认中文                          | ✅   |
| 开机自启        | SMAppService                      | ✅   |
| 自动更新        | GitHub Release 检测               | ✅   |
| DMG 打包        | 一键构建分发包                    | ✅   |
| GitHub Actions  | 自动构建 x86+ARM Universal Binary | ✅   |

## 4. UI 设计规范

### 设计风格

- 灵感来源：Withings Health Dashboard
- 暗色主题为主 (#0D1117)，青绿强调色 (#00D4AA)
- 圆角卡片布局，左侧边栏 + 右侧内容区
- 900×600 默认窗口大小

### 色彩体系

| 元素 | 暗色      | 亮色      |
| ---- | --------- | --------- |
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

## 7. Cloudflare Tunnel 集成

### 7.1 方案

集成 `cloudflared` CLI，用户可在设置中一键开启 Cloudflare Tunnel，实现：

- 将本地 Ollama Gateway 端口直接暴露到公网
- 无需公网 IP、无需端口转发、自动 HTTPS
- 使用 `cloudflared tunnel --url http://localhost:<port>` 快速隧道模式

### 7.2 技术实现

- 自动检测 `cloudflared` 是否安装（`which cloudflared`）
- 未安装时提示用户通过 `brew install cloudflared` 安装
- 使用 `Process` (Foundation) 启动/停止 `cloudflared` 进程
- 捕获 stdout/stderr 解析隧道 URL（`*.trycloudflare.com`）
- 隧道 URL 显示在设置面板中，支持一键复制
- 隧道状态独立于代理服务器，可单独启停

### 7.3 状态模型

```swift
enum TunnelStatus {
    case stopped
    case downloading
    case starting
    case running(url: String)
    case error(String)
}
```

### 7.4 UI 位置

在 SettingsView 中新增 "Cloudflare Tunnel" section，包含：

- 启动/停止按钮
- 隧道状态指示
- 公网 URL 显示 + 复制按钮
- 安装引导链接

## 8. v1.1 UI 优化

### 8.1 玻璃拟态效果

- 侧边栏、卡片背景使用 `.ultraThinMaterial` / `.thinMaterial`
- 顶部 Tab Bar 使用 `.bar` material
- 整体增加磨砂玻璃质感，突出高级感

### 8.2 Logo 修正

- App Icon: 使用 `./logo.icns`（已裁剪）
- Status Bar Icon: 使用 `./statuslogo.icns`
- 软件内 Logo: 使用 StatusBarIcon 资源
- Status Bar 图标设置 `isTemplate = true`，确保正确渲染

### 8.3 密钥查看

- API Key 列表中增加"眼睛"图标切换显示/隐藏完整密钥

### 8.4 端口说明

- 监听端口旁增加感叹号图标 + Popover 说明反代用途

## 9. 非目标

- 不替代 Docker 部署（Python 版本保留）
- 不做 Windows/Linux 版本
- 不做用户权限管理系统

## 10. v1.2 功能增强

### 10.1 GitHub Actions CI 修复

- tag 格式从 `v*.*.*` 改为同时支持 `*.*.*`（无 v 前缀）
- `macos-13` runner 已废弃，改为 `macos-14` 统一构建，通过 `--arch x86_64` 交叉编译
- `build.sh` 支持 `ARCH` 环境变量交叉编译
- `create-dmg.sh` 使用 `ARCH` 环境变量命名 DMG
- Release body 增加完整 changelog、签名修复说明

### 10.2 内嵌 cloudflared 零依赖

- 应用启动时自动检测/下载 cloudflared 二进制到 `~/Library/Application Support/OllamaGateway/`
- 无需用户手动安装 brew，真正零依赖
- 从 GitHub Releases 下载对应架构 (arm64/amd64) 的 cloudflared

### 10.3 DMG 签名提示

- README 中添加 `xattr -cr` 命令，解决 macOS 安全提示

### 10.4 README 中英文分离

- `README.md` 为中文主文档
- `README_EN.md` 为英文文档
- 顶部互相链接

### 10.5 UI 全局统一

- 按钮颜色统一使用 `theme.accent` 替代硬编码 amber/orange
- 标题栏无缝融合 `.titlebar` transparent
- 应用标题栏与内容区颜色一致

### 10.6 通用设置增强

- 自动启动 Cloudflare Tunnel 开关
- 隐藏 Dock 图标开关（LSUIElement 动态切换）
- 关闭窗口时保持后台运行，状态栏图标常驻

### 10.7 磨玻璃 + 动效增强

- 侧边栏状态指示灯呼吸动画
- 按钮 hover 效果
- 数字变化动画 `.contentTransition(.numericText())`
- 卡片进场动画

### 10.8 自动更新完善

- 检测到新版本后显示下载进度
- 自动下载 DMG 到临时目录并打开
- 显示当前版本 vs 远程版本对比

### 10.9 日志系统增强

- 错误状态码旁显示感叹号，点击弹窗解释（401=Key错误 等）
- 日志保存/导出功能，用户选择路径导出标准日志文件
- 日志区域固定高度+滚动条，限制显示前 100 条

### 10.10 状态栏菜单修复

- 点击状态栏图标弹出窗口
- "服务运行中" → "Ollama Gateway: 运行中"
