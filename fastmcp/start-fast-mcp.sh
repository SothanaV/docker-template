python3 -m venv env
source env/bin/activate
pip install fastmcp "uvicorn[standard]"
mkdir -p server
cat > server/server.py << 'EOF'
from fastmcp import FastMCP

mcp = FastMCP("MCP Server")

@mcp.tool
async def echo(message: str) -> str:
    return message

app = mcp.http_app(path='/mcp')

EOF
pip freeze > server/requirements.txt