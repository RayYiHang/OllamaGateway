import os
import secrets
from contextlib import asynccontextmanager

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse

HOP_HEADERS = frozenset(
    {"content-length", "transfer-encoding", "connection", "keep-alive"}
)

load_dotenv()

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
API_KEYS: set[str] = set(
    k.strip() for k in os.getenv("API_KEYS", "").split(",") if k.strip()
)

if not API_KEYS:
    raise RuntimeError("API_KEYS environment variable is required")

http_client: httpx.AsyncClient


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global http_client
    http_client = httpx.AsyncClient(base_url=OLLAMA_BASE_URL, timeout=None)
    yield
    await http_client.aclose()


app = FastAPI(title="Ollama Auth Gateway", lifespan=lifespan)


def verify_api_key(request: Request) -> None:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing API key")
    token = auth.removeprefix("Bearer ").strip()
    if not any(secrets.compare_digest(token, k) for k in API_KEYS):
        raise HTTPException(status_code=401, detail="Invalid API key")


@app.get("/")
async def health():
    try:
        r = await http_client.get("/")
        return {"status": "ok", "ollama": r.status_code == 200}
    except httpx.ConnectError:
        return {"status": "ok", "ollama": False}


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(request: Request, path: str):
    verify_api_key(request)

    # Build upstream request
    url = f"/{path}"
    headers = {
        k: v
        for k, v in request.headers.items()
        if k.lower() not in ("host", "authorization")
    }
    body = await request.body()

    req = http_client.build_request(
        method=request.method,
        url=url,
        headers=headers,
        content=body,
        params=request.query_params,
    )
    upstream = await http_client.send(req, stream=True)

    # Stream response back
    async def stream():
        async for chunk in upstream.aiter_bytes():
            yield chunk
        await upstream.aclose()

    resp_headers = {
        k: v
        for k, v in upstream.headers.items()
        if k.lower() not in HOP_HEADERS
    }

    return StreamingResponse(
        stream(),
        status_code=upstream.status_code,
        headers=resp_headers,
    )
