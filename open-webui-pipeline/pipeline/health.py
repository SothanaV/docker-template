"""Health check endpoint for Open WebUI Pipelines."""
import requests
import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse


app = FastAPI(name="pipeline-health")


@app.get("/healthz")
async def healthz():
    status = {"status": "healthy", "service": "open-webui-pipeline"}
    
    # Check Open WebUI endpoint
    try:
        webui_host = os.getenv("OPEN_WEBUI_HOST", "localhost")
        webui_url = f"http://{webui_host}:8080/health"
        r = requests.get(webui_url, timeout=5)
        if r.status_code == 200:
            status["open-webui"] = "connected"
        else:
            status["open-webui"] = "unhealthy"
            status["status"] = "degraded"
    except Exception as e:
        status["open-webui"] = f"disconnected: {str(e)}"
        status["status"] = "degraded"
    
    code = 503 if status["status"] != "healthy" else 200
    return JSONResponse(content=status, status_code=code)
