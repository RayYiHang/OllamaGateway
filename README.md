<p align="center">
  <img src="logo.png" width="128" height="128" alt="Ollama Gateway">
</p>

<h1 align="center">Ollama Gateway</h1>

<p align="center">
  <strong>为 Ollama 添加 API Key 鉴权的原生 macOS 应用 + 轻量级反向代理网关</strong>
</p>

<p align="center">
  <a href="#-安装"><img src="https://img.shields.io/badge/macOS-13.0+-000000?logo=apple&logoColor=white" alt="macOS"></a>
  <a href="https://github.com/OWNER/ollamafastapi/releases/latest"><img src="https://img.shields.io/github/v/release/OWNER/ollamafastapi?color=00D4AA&label=Download" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue" alt="License"></a>
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/Zero_Dependencies-✓-00D4AA" alt="Zero Deps">
  <img src="https://img.shields.io/github/actions/workflow/status/OWNER/ollamafastapi/release.yml?label=CI" alt="CI">
</p>

<p align="center">
  <sub>原生 Swift · 零依赖 · 3MB 极简体积 · 开箱即用</sub>
</p>

---

## ✨ 特性

- 🖥️ **原生 macOS 应用** — SwiftUI 构建，零外部依赖，仅 3MB
- 🔐 **API Key 鉴权** — Bearer Token 认证，保护你的 Ollama 服务
- 📊 **实时 Dashboard** — 请求统计、延迟监控、成功率、活动图表
- 🌐 **透明代理** — 完整支持流式响应（SSE），兼容所有 Ollama API
- 🌙 **明暗主题** — 深色/浅色/跟随系统，灵感来自 Withings 设计
- 🌍 **中英双语** — 默认中文，一键切换
- 📌 **状态栏常驻** — Menu Bar + Dock 双图标，随时控制
- 🚀 **开机自启** — 系统级 Login Item 支持
- 🔄 **自动更新** — 自动检测 GitHub 新版本
- 🐳 **Docker 可选** — 同时提供 Python FastAPI 版本用于服务器部署

## 📥 安装

### 方式一：下载 DMG（推荐）

前往 [Releases](https://github.com/OWNER/ollamafastapi/releases/latest) 下载对应架构的 `.dmg`：

| 芯片 | 文件 |
|------|------|
| Apple Silicon (M1/M2/M3/M4) | `OllamaGateway-vX.X.X-arm64.dmg` |
| Intel | `OllamaGateway-vX.X.X-x86_64.dmg` |

打开 DMG → 拖入 Applications → 首次启动右键"打开"。

### 方式二：从源码构建

```bash
git clone https://github.com/OWNER/ollamafastapi.git
cd ollamafastapi
bash scripts/build.sh release
open build/OllamaGateway.app
```

> 需要 macOS 13+ 和 Xcode Command Line Tools

## 🚀 快速开始

1. **打开应用** → 进入 Settings 标签页
2. **配置 Ollama 地址** → 默认 `http://localhost:11434`
3. **添加 API Key** → 点击"生成随机密钥"或手动输入
4. **启动服务** → 点击左下角「启动」按钮
5. **使用网关** →

```bash
# 健康检查
curl http://localhost:8000/

# 对话（需鉴权）
curl http://localhost:8000/api/chat \
  -H "Authorization: Bearer sk-your-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5", "messages": [{"role": "user", "content": "hello"}]}'
```

## 🏗️ 架构

```
Client → Ollama Gateway (:8000) → Ollama (:11434)
              │
         API Key 验证
         请求日志记录
         流式响应转发
```

**技术栈**：纯 Swift + SwiftUI + Network.framework + URLSession

- HTTP 服务器：`NWListener`（零依赖，系统框架）
- HTTP 客户端：`URLSession`（原生流式传输）
- GUI：SwiftUI（声明式 UI）
- 无任何第三方库

## 🐳 Docker 部署（服务器版）

同时提供 Python FastAPI 版本，适用于 Linux 服务器 / Docker 部署：

```bash
# 配置环境变量
echo "API_KEYS=sk-your-key-1,sk-your-key-2" > .env
echo "OLLAMA_BASE_URL=http://localhost:11434" >> .env

# Docker 运行
docker build -t ollama-gateway .
docker run -d --name ollama-gateway \
  --env-file .env \
  --network host \
  -p 8000:8000 \
  ollama-gateway
```

<details>
<summary>直接运行（不用 Docker）</summary>

```bash
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

</details>

## 📁 项目结构

```
├── Package.swift                    # Swift 项目（零依赖）
├── Sources/OllamaGateway/
│   ├── OllamaGatewayApp.swift       # 应用入口 + StatusBar
│   ├── ProxyServer.swift            # HTTP 反向代理服务器
│   ├── AppState.swift               # 数据模型 + 状态管理
│   ├── Services.swift               # 健康检测 + 更新检查
│   ├── MainView.swift               # 主窗口布局
│   ├── DashboardView.swift          # 仪表盘
│   ├── SettingsView.swift           # 设置面板
│   ├── Components.swift             # UI 组件库
│   ├── Theme.swift                  # 主题系统
│   └── Localization.swift           # 中英文本地化
├── scripts/                         # 构建 & 打包脚本
├── .github/workflows/release.yml    # CI/CD（自动构建双架构）
├── main.py                          # Python 版本（Docker 用）
├── Dockerfile
└── docs/PLAN.md
```

## ⚙️ 配置

| 项目 | 默认值 | 说明 |
|------|--------|------|
| Ollama Base URL | `http://localhost:11434` | Ollama 服务地址 |
| Server Port | `8000` | 网关监听端口 |
| API Keys | — | 鉴权密钥（支持多个） |

所有配置通过应用 GUI 管理，持久化在 UserDefaults 中。

## 🔄 自动更新

应用启动时自动检查 GitHub Releases，发现新版本弹窗提示下载。

## 🛠️ 开发

```bash
# 克隆
git clone https://github.com/OWNER/ollamafastapi.git && cd ollamafastapi

# 开发构建
swift build

# Release 构建 + 打包 DMG
bash scripts/build.sh release
bash scripts/create-dmg.sh

# 发布新版本
git tag v1.0.1 && git push origin v1.0.1
# → GitHub Actions 自动构建 arm64 + x86_64 DMG
```

## 📋 API 行为

| 端点 | 鉴权 | 说明 |
|------|------|------|
| `GET /` | ✗ | 健康检查 |
| `/{path}` | ✓ Bearer Token | 透明代理到 Ollama |

兼容所有 OpenAI 格式客户端（Cursor、Continue、Open WebUI 等）。

## 🤝 贡献

欢迎 PR 和 Issue！中文和英文均可。

## 📄 License

[MIT](LICENSE)
