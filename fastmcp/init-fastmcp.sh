#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name>"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating FastMCP project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

# Interactive menu
read -p "${CYAN}Enter MCP server port [default: 8090]: ${NC}" MCP_PORT
MCP_PORT=${MCP_PORT:-8090}

read -p "${CYAN}Enable SSE transport? (y/N) [default: Y]: ${NC}" USE_SSE
USE_SSE=${USE_SSE^^}
USE_SSE=${USE_SSE:-Y}

read -p "${CYAN}Enable stdio mode? (y/N) [default: N]: ${NC}" USE_STDIO
USE_STDIO=${USE_STDIO^^}
USE_STDIO=${USE_STDIO:-N}

read -p "${CYAN}Python version [default: 3.12]: ${NC}" PYTHON_VERSION
PYTHON_VERSION=${PYTHON_VERSION:-3.12}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

# .env
create_file "$PROJECT_DIR/.env" "# FastMCP Environment Configuration
PROJECT_NAME=$PROJECT_NAME
MCP_PORT=$MCP_PORT
PYTHON_VERSION=$PYTHON_VERSION

# MCP Transport mode: sse, stdio, or both
MCP_TRANSPORT=both

# Enable debug logging
DEBUG=false

# SSE endpoint path
SSE_PATH=/sse

# stdio mode path
STDIO_PATH=/stdio

# Allowed origins for CORS
CORS_ORIGINS=*"
"

# docker-compose.yml
{
cat <<YAML
services:
  fastmcp:
    container_name: \${PROJECT_NAME:-fastmcp}-app
    build:
      context: .
      dockerfile: server/Dockerfile
      args:
        PYTHON_VERSION: \${PYTHON_VERSION:-3.12}
    ports:
      - "\${MCP_PORT:-8090}:\${MCP_PORT:-8090}"
    volumes:
      - ./server:/app
      - /app/.venv
    environment:
      - PROJECT_NAME=\${PROJECT_NAME}
      - MCP_PORT=\${MCP_PORT:-8090}
      - PYTHON_VERSION=\${PYTHON_VERSION}
      - MCP_TRANSPORT=\${MCP_TRANSPORT:-both}
      - DEBUG=\${DEBUG:-false}
      - CORS_ORIGINS=\${CORS_ORIGINS:-*}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:\${MCP_PORT:-8090}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
YAML
if [ "$USE_SSE" = "Y" ]; then
    cat <<YAML
  fastmcp-sse:
    container_name: \${PROJECT_NAME:-fastmcp}-sse
    image: python:\${PYTHON_VERSION:-3.12}-slim
    ports:
      - "\$((MCP_PORT + 1)):\$((MCP_PORT + 1))"
    volumes:
      - ./server:/app
    environment:
      - MCP_TRANSPORT=sse
      - MCP_PORT=\$((MCP_PORT + 1))
    command: python -m fastmcp serve sse://0.0.0.0:\$((MCP_PORT + 1))
    restart: unless-stopped
    depends_on:
      - fastmcp
YAML
fi
cat <<'YAML'
volumes:
YAML
echo "  fastmcp-venv:"

} > "$PROJECT_DIR/docker-compose.yml"

# server/Dockerfile
create_file "$PROJECT_DIR/server/Dockerfile" "FROM python:\${PYTHON_VERSION:-3.12}-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s \\
    CMD curl -f http://localhost:8090/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8090"]
"

# server/main.py template
create_file "$PROJECT_DIR/server/main.py" "# FastMCP Server Application

from fastmcp import Server, Context
from contextlib import asynccontextmanager
import os
import sys
import httpx
from typing import Optional

project_name = os.getenv("PROJECT_NAME", "fastmcp")
mcp_port = int(os.getenv("MCP_PORT", "8090"))

@asynccontextmanager
async def server_lifespan(server: Server):
    print(f"FastMCP server starting: {project_name}")
    yield
    print(f"FastMCP server shutting down: {project_name}")

app = Server(project_name, lifespan=server_lifespan)

@app.tool()
async def health_check():
    \"\"\"Check server health and status.\"\"\"
    return {
        "status": "healthy",
        "service": "fastmcp",
        "project": project_name,
        "port": mcp_port
    }

@app.tool()
async def get_env_info():
    \"\"\"Get environment information.\"\"\"
    return {
        "project_name": project_name,
        "mcp_port": mcp_port,
        "python_version": sys.version,
        "transport": os.getenv("MCP_TRANSPORT", "both")
    }

# MCP Tools can be added here
# Use @app.tool() decorator to expose functions as MCP tools
"

# server/requirements.txt
create_file "$PROJECT_DIR/server/requirements.txt" "fastmcp>=0.1.0
uvicorn[standard]>=0.29.0
httpx>=0.27.0
pydantic>=2.7.0
python-dotenv>=1.0.0
"

# start-all.sh
create_file "$PROJECT_DIR/start-all.sh" '#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting FastMCP services..."

if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed"
    exit 1
fi

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "Error: docker-compose not found"
    exit 1
fi

echo "Using: $COMPOSE_CMD"
$COMPOSE_CMD down 2>/dev/null || true
$COMPOSE_CMD up --build -d

echo -e "\033[0;32mFastMCP started!\033[0m"
echo -e "MCP Port: \033[1;33m$MCP_PORT${MCP_PORT:-8090}\033[0m"
echo -e "Health: \033[1;33mhttp://localhost:$MCP_PORT${MCP_PORT:-8090}/health\033[0m"
echo -e "Logs: \033[1;33m$COMPOSE_CMD logs -f\033[0m"
echo -e "Stop: \033[1;33m$COMPOSE_CMD down\033[0m"
'

# stop-all.sh
create_file "$PROJECT_DIR/stop-all.sh" '#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "Error: docker-compose not found"
    exit 1
fi

echo "Stopping FastMCP services..."
$COMPOSE_CMD down
echo "Services stopped!"
'

# .dockerignore
create_file "$PROJECT_DIR/.dockerignore" "__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/

# Git
.git/

# IDE
.vscode/
.idea/

# Docker
docker-compose.override.yml

# Docs
*.md

# OS
.DS_Store
"

# .gitignore
create_file "$PROJECT_DIR/.gitignore" "__pycache__/
*.egg-info/
.venv/
venv/
*.egg

# Environment
.env

# IDE
.vscode/
.idea/

# OS
.DS_Store
"

# README.md
create_file "$PROJECT_DIR/README.md" "# $PROJECT_NAME

FastMCP - MCP Server for AI

Model Context Protocol (MCP) server that provides tools for AI assistant integration.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- MCP Server: Port ${MCP_PORT:-8090}
- Health Check: http://localhost:${MCP_PORT:-8090}/health

## Configuration

Edit \`.env\`:
- \`MCP_PORT\`: Server port
- \`MCP_TRANSPORT\`: Transport mode (sse, stdio, both)
- \`DEBUG\`: Enable debug logging

## MCP Tools

The server exposes tools via the MCP protocol. Connect using any MCP client.

\`\`\`bash
# View logs
docker compose logs -f
\`\`\`
"

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FastMCP project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "MCP Port: ${YELLOW}${MCP_PORT:-8090}${NC}"
echo ""
