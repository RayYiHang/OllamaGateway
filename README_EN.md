<p align="center">
  <img src="logo.png" width="128" height="128" alt="Ollama Gateway">
</p>

<h1 align="center">Ollama Gateway</h1>

<p align="center">
  <strong>A native macOS app that adds API Key authentication to Ollama + one-click Cloudflare Tunnel for public access</strong>
</p>

<p align="center">
  <a href="#-installation"><img src="https://img.shields.io/badge/macOS-13.0+-000000?logo=apple&logoColor=white" alt="macOS"></a>
  <a href="https://github.com/RayYiHang/OllamaGateway/releases/latest"><img src="https://img.shields.io/github/v/release/RayYiHang/OllamaGateway?color=00D4AA&label=Download" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue" alt="License"></a>
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/Zero_Dependencies-✓-00D4AA" alt="Zero Deps">
  <a href="https://github.com/RayYiHang/OllamaGateway/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/RayYiHang/OllamaGateway/release.yml?label=CI" alt="CI"></a>
</p>

<p align="center">
  <sub>Native Swift · Zero Dependencies · Lightweight · Glassmorphism UI · One-click Public Access</sub>
</p>

<p align="center">
  English · <a href="README.md">中文</a>
</p>

---

## ✨ Features

- 🖥️ **Native macOS App** — SwiftUI + frosted glass UI, zero external dependencies
- 🔐 **API Key Auth** — Bearer Token authentication to protect your Ollama service
- 🌐 **Cloudflare Tunnel** — One-click public exposure with automatic HTTPS, built-in cloudflared auto-download
- 📊 **Real-time Dashboard** — Request stats, latency monitoring, success rate, activity charts, error status hints
- 🔄 **Transparent Proxy** — Full SSE streaming support, compatible with all Ollama APIs (including Cloud models)
- 🌙 **Dark/Light Theme** — Dark/Light/System with glassmorphism aesthetics
- 🌍 **Bilingual** — Chinese (default) + English, one-click switch
- 📌 **Menu Bar** — Status bar icon with left-click to show window, right-click for menu
- 🚀 **Launch at Login** — System-level Login Item support
- 🔄 **Auto Update** — Automatic GitHub release detection with one-click download
- 🙈 **Hide Dock** — Optionally hide Dock icon, keeping only menu bar
- ☁️ **Auto Tunnel** — Optionally auto-start Cloudflare Tunnel with the server
- 💾 **Export Logs** — Export request logs as CSV files
- 🐳 **Docker Alternative** — Python FastAPI version for server deployment

## 📥 Installation

### Option 1: Download DMG (Recommended)

Go to [Releases](https://github.com/RayYiHang/OllamaGateway/releases/latest) and download the `.dmg` for your architecture:

| Chip                        | File                              |
| --------------------------- | --------------------------------- |
| Apple Silicon (M1/M2/M3/M4) | `OllamaGateway-vX.X.X-arm64.dmg`  |
| Intel                       | `OllamaGateway-vX.X.X-x86_64.dmg` |

Open DMG → Drag to Applications → First launch: right-click → "Open".

> ⚠️ **macOS Signature Note**: Since the app is unsigned, macOS may block it on first launch. Run in Terminal:
>
> ```bash
> xattr -cr /Applications/OllamaGateway.app
> ```
>
> Then double-click to launch normally.

### Option 2: Build from Source

```bash
git clone https://github.com/RayYiHang/OllamaGateway.git
cd OllamaGateway
bash scripts/build.sh release
open build/OllamaGateway.app
```

> Requires macOS 13+ and Xcode Command Line Tools

## 🚀 Quick Start

1. **Open the app** → Go to Settings tab
2. **Configure Ollama URL** → Default `http://localhost:11434`
3. **Add API Key** → Click "Generate Random Key" or enter manually
4. **Start Server** → Click the "Start" button in the bottom-left
5. **Use the Gateway** →

```bash
# Health check
curl http://localhost:8000/

# Chat (auth required)
curl http://localhost:8000/api/chat \
  -H "Authorization: Bearer sk-your-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5", "messages": [{"role": "user", "content": "hello"}]}'
```

### 🌐 One-Click Public Access

1. App → Settings → Cloudflare Tunnel → Click "Start"
2. The app will auto-download cloudflared on first use
3. Get a `*.trycloudflare.com` HTTPS URL
4. Share this URL for remote access to your Ollama service

> 💡 Enable "Auto-start Tunnel" in settings to start automatically with the server.

### ⚙️ Ollama Environment Variables

If you encounter connection issues or Cloud model 404 errors, configure these Ollama environment variables:

```bash
# Allow all origins (recommended when using a reverse proxy)
launchctl setenv OLLAMA_ORIGINS "*"

# To allow remote access to Ollama
launchctl setenv OLLAMA_HOST "0.0.0.0:11434"
```

> Restart the Ollama app after setting these. The gateway already forwards the correct Host header for Ollama compatibility.

## 🏗️ Architecture

```
Client → Ollama Gateway (:8000) → Ollama (:11434)
              │
         API Key Validation
         Host Header Forwarding
         Request Logging
         Streaming Forward
              │
     Cloudflare Tunnel (optional)
              │
         Public HTTPS Access
```

**Tech Stack**: Pure Swift + SwiftUI + Network.framework + URLSession

- HTTP Server: `NWListener` (zero dependencies, system framework)
- HTTP Client: `URLSession` (native streaming)
- GUI: SwiftUI (frosted glass Material Design)
- Tunnel: Built-in `cloudflared` auto-download management
- No third-party libraries

## 🐳 Docker Deployment (Server Version)

A Python FastAPI version is also provided for Linux server / Docker deployment:

```bash
# Configure environment
echo "API_KEYS=sk-your-key-1,sk-your-key-2" > .env
echo "OLLAMA_BASE_URL=http://localhost:11434" >> .env

# Docker run
docker build -t ollama-gateway .
docker run -d --name ollama-gateway \
  --env-file .env \
  --network host \
  -p 8000:8000 \
  ollama-gateway
```

<details>
<summary>Run directly (without Docker)</summary>

```bash
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

</details>

## 📁 Project Structure

```
├── Package.swift                     # Swift project (zero dependencies)
├── Sources/OllamaGateway/
│   ├── OllamaGatewayApp.swift        # App entry + StatusBar
│   ├── ProxyServer.swift             # HTTP reverse proxy (with Host header forwarding)
│   ├── AppState.swift                # Data models + state management
│   ├── Services.swift                # Health check + update checker
│   ├── CloudflareTunnel.swift        # Cloudflare Tunnel (auto-download)
│   ├── MainView.swift                # Main window layout
│   ├── DashboardView.swift           # Dashboard
│   ├── SettingsView.swift            # Settings panel
│   ├── Components.swift              # UI component library
│   ├── Theme.swift                   # Theme system
│   └── Localization.swift            # Chinese/English localization
├── scripts/                          # Build & package scripts
├── .github/workflows/release.yml     # CI/CD (dual architecture builds)
├── main.py                           # Python version (for Docker)
├── Dockerfile
└── docs/PLAN.md
```

## ⚙️ Configuration

| Setting         | Default                  | Description                        |
| --------------- | ------------------------ | ---------------------------------- |
| Ollama Base URL | `http://localhost:11434` | Ollama service address             |
| Server Port     | `8000`                   | Gateway listening port             |
| API Keys        | —                        | Auth keys (multiple supported)     |
| CF Tunnel       | Off                      | One-click Cloudflare public access |
| Hide Dock       | Off                      | Keep only menu bar icon            |
| Auto Tunnel     | Off                      | Auto-start tunnel with server      |

All settings are managed through the app GUI and persisted in UserDefaults.

## 🛠️ Development

```bash
# Clone
git clone https://github.com/RayYiHang/OllamaGateway.git && cd OllamaGateway

# Development build
swift build

# Release build + package DMG
bash scripts/build.sh release
bash scripts/create-dmg.sh

# Publish new version
git tag 1.0.0 && git push origin 1.0.0
# → GitHub Actions auto-builds arm64 + x86_64 DMG
```

## 📋 API Behavior

| Endpoint  | Auth           | Description                 |
| --------- | -------------- | --------------------------- |
| `GET /`   | ✗              | Health check                |
| `/{path}` | ✓ Bearer Token | Transparent proxy to Ollama |

Compatible with all OpenAI-format clients (Cursor, Continue, Open WebUI, etc.).

## 🤝 Contributing

PRs and Issues welcome! Both Chinese and English are fine.

## 📄 License

[MIT](LICENSE)
