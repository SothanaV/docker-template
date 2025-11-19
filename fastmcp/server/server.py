from fastmcp import FastMCP

# Create the MCP server instance
mcp = FastMCP("RCA MCP Server")


@mcp.tool
def add(a: int, b: int) -> int:
    """
    Add two integers and return the result.
    """
    return a + b


@mcp.tool
async def echo(message: str) -> str:
    """
    Echo a message back.
    """
    return message

app = mcp.http_app(path='/mcp')