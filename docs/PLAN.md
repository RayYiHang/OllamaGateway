# Ollama FastAPI Auth Gateway — Plan & Spec

## 1. 项目目标

为本地运行的 Ollama 提供一个轻量级 FastAPI 鉴权反向代理网关，通过 Cloudflare Tunnel 安全地暴露到公网。

```
Client (公网)
  │
  ▼
Cloudflare Tunnel
  │
  ▼
FastAPI Auth Gateway (:8000)   ← API Key 鉴权
  │
  ▼
Ollama (:11434)                ← 本地无鉴权
```

## 2. 核心需求

| # | 需求 | 说明 |
|---|------|------|
| 1 | API Key 鉴权 | 通过 `Authorization: Bearer <api-key>` 请求头验证 |
| 2 | 透明代理 | 将所有合法请求原样转发到 Ollama，包括流式响应（SSE） |
| 3 | 多 Key 支持 | 支持配置多个 API Key |
| 4 | 环境变量配置 | Ollama 地址、API Keys 均通过环境变量 / `.env` 文件配置 |
| 5 | 最小依赖 | 仅 FastAPI + httpx + uvicorn |

## 3. 技术方案

### 3.1 鉴权方式

- 标准 HTTP Bearer Token：`Authorization: Bearer sk-xxxxx`
- 多 Key 以逗号分隔存于环境变量 `API_KEYS`
- 未携带/错误 Key 返回 `401 Unauthorized`

### 3.2 代理转发

- 使用 `httpx.AsyncClient` 异步转发请求到 Ollama
- 支持流式响应（`StreamingResponse`），适配 `/api/chat`、`/api/generate` 等流式接口
- 转发所有 HTTP 方法（GET/POST/DELETE 等）

### 3.3 配置项

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama 服务地址 |
| `API_KEYS` | (必填) | 逗号分隔的 API Key 列表 |

### 3.4 项目结构

```
ollamafastapi/
├── main.py          # 入口：FastAPI 应用 + 代理逻辑
├── .env.example     # 环境变量示例
├── requirements.txt # 依赖
├── Dockerfile       # 容器化部署（可选）
└── README.md        # 使用说明
```

## 4. API 行为

- `GET /` — 健康检查（无需鉴权）
- `/{path:path}` — 所有其他路径透明代理到 Ollama（需鉴权）

## 5. 非目标

- 不做限流（可由 Cloudflare 处理）
- 不做日志持久化
- 不做用户管理系统
