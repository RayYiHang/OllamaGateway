# Ollama Auth Gateway

为 Ollama 添加 API Key 鉴权的轻量级 FastAPI 反向代理，适用于通过 Cloudflare Tunnel 暴露到公网的场景。

```
Client → Cloudflare Tunnel → FastAPI Gateway (鉴权) → Ollama
```

## 快速开始

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env，设置你的 API Key

# 3. 启动网关
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 配置

在 `.env` 文件中配置：

```env
OLLAMA_BASE_URL=http://localhost:11434
API_KEYS=sk-your-key-1,sk-your-key-2
```

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama 地址 |
| `API_KEYS` | (必填) | 逗号分隔的 API Key |

## 使用

所有请求需携带 `Authorization: Bearer <your-api-key>` 头：

```bash
# 健康检查（无需鉴权）
curl http://localhost:8000/

# 对话（需鉴权）
curl http://localhost:8000/api/chat \
  -H "Authorization: Bearer sk-your-key-1" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5", "messages": [{"role": "user", "content": "hello"}]}'

# 列出模型
curl http://localhost:8000/api/tags \
  -H "Authorization: Bearer sk-your-key-1"
```

## 配合 Cloudflare Tunnel

```bash
# 安装 cloudflared 后
cloudflared tunnel --url http://localhost:8000
```

这会生成一个公网 URL，所有请求都会经过 API Key 鉴权后才能访问 Ollama。

## Docker 部署

```bash
docker build -t ollama-gateway .
docker run -d --name ollama-gateway \
  --env-file .env \
  --network host \
  -p 8000:8000 \
  ollama-gateway
```

## 项目结构

```
├── main.py          # FastAPI 应用（~70 行）
├── .env.example     # 环境变量模板
├── requirements.txt # 依赖
├── Dockerfile       # 容器化部署
└── docs/PLAN.md     # 设计文档
```

## License

MIT
