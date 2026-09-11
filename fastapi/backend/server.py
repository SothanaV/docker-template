from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI()


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/healthz")
async def healthz():
    return JSONResponse(content={"status": "healthy", "service": "fastapi"})
