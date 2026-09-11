from fastapi import FastAPI
from fastmcp import FastMCP

mcp = FastMCP("MCP Server")


@mcp.tool
def add(a: int, b: int) -> int:
    """Add two integers and return the result."""
    return a + b


@mcp.tool
async def echo(message: str) -> str:
    """Echo a message back."""
    return message


mcp_app = mcp.http_app(path="/mcp")

app = FastAPI(title="MCP Server", lifespan=mcp_app.lifespan)


@app.get("/healthz")
async def healthz():
    return {"status": "healthy", "service": "fastmcp"}


app.mount("/", mcp_app)
