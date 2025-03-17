from fastapi import FastAPI, Request, Path
import httpx
from fastapi.responses import StreamingResponse
from starlette.background import BackgroundTask
from itertools import cycle

app = FastAPI()



OLLAMA_HOSTS = {
    "large_model": "http://ollama-1:11434",
    "small_model": cycle([
        "http://ollama-2:11434",
        "http://ollama-3:11434",
        "http://ollama-4:11434"
    ])
}

list_small_model = ["gemma3:12b"]


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy(path: str, request: Request):
    # Read request JSON (if applicable)
    stream = False
    try:
        body = await request.json()
        model = body.get("model", "")
        stream = body.get('stream', False)
    except Exception:
        model = ""

    # Determine target host based on model
    if model in list_small_model:
        target_host = next(OLLAMA_HOSTS["small_model"])
    else:
        target_host = OLLAMA_HOSTS["large_model"]

    # Build target URL
    target_url = f"{target_host}/{path}"

    print(target_url, f"stream : {stream}")

    # Forward the request
    client = httpx.AsyncClient(
        timeout=None, 
        limits=httpx.Limits(
            max_keepalive_connections=40, 
            max_connections=200, 
            keepalive_expiry=10
        )
    )
    if stream:
        req = client.build_request(
            request.method, target_url, headers=dict(request.headers), content=await request.body()
        )
        response = await client.send(req, stream=True)
        return StreamingResponse(
            response.aiter_bytes(),
            status_code=response.status_code,
            headers=dict(response.headers),
            background=BackgroundTask(response.aclose),
        )
    response = await client.request(
        method=request.method,
        url=target_url,
        headers=request.headers.raw,
        content=await request.body(),
        timeout=None
    )
    # Return response
    return response.json()