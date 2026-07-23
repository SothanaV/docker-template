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

echo -e "${GREEN}Creating Open WebUI project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 3000]: ${NC}" WEBUI_PORT
WEBUI_PORT=${WEBUI_PORT:-3000}

read -p "${CYAN}Use Ollama? (y/N) [default: Y]: ${NC}" USE_OLLAMA
USE_OLLAMA=${USE_OLLAMA^^}
USE_OLLAMA=${USE_OLLAMA:-Y}

read -p "${CYAN}Ollama URL [default: http://host.docker.internal:11434]: ${NC}" OLLAMA_URL
OLLAMA_URL=${OLLAMA_URL:-http://host.docker.internal:11434}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: N]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-N}

read -p "${CYAN}Enable OAuth? (y/N) [default: N]: ${NC}" USE_OAUTH
USE_OAUTH=${USE_OAUTH^^}
USE_OAUTH=${USE_OAUTH:-N}

read -p "${CYAN}WebUI version [default: latest]: ${NC}" WEBUI_VERSION
WEBUI_VERSION=${WEBUI_VERSION:-latest}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

{
cat <<EOF
# Open WebUI Environment Configuration
PROJECT_NAME=$PROJECT_NAME
WEBUI_PORT=$WEBUI_PORT
WEBUI_VERSION=$WEBUI_VERSION

# Ollama Connection
EOF
if [ "$USE_OLLAMA" = "Y" ]; then
    cat <<EOF
OLLAMA_BASE_URL=$OLLAMA_URL
EOF
fi
cat <<EOF

# Database
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/openwebui
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=openwebui
EOF
fi
cat <<EOF

# OAuth (optional)
EOF
if [ "$USE_OAUTH" = "Y" ]; then
    cat <<EOF
ENABLE_OAUTH=true
OAUTH_PROVIDER=openid
OAUTH_PROVIDER_NAME=OpenID
OAUTH_CONFIG_URL=
OAUTH_CLIENT_ID=
OAUTH_CLIENT_SECRET=
OAUTH_SCOPES=openid email profile
OAUTH_REDIRECT_URL=http://localhost:$WEBUI_PORT/oauth/callback
EOF
fi
cat <<EOF

# Server
WEBUI_SECRET_KEY=changeme-to-something-secure
EOF
} > "$PROJECT_DIR/.env"

{
cat <<EOF
services:
  webui:
    container_name: \${PROJECT_NAME:-open-webui}-app
    image: \${WEBUI_IMAGE:-ghcr.io/open-webui/open-webui}:\${WEBUI_VERSION:-latest}
    ports:
      - "\${WEBUI_PORT:-3000}:8080"
    volumes:
      - \${PROJECT_NAME:-open-webui-data}:/app/backend/data
    environment:
      - WEBUI_PORT=8080
EOF
if [ "$USE_OLLAMA" = "Y" ]; then
    cat <<EOF
      - OLLAMA_BASE_URL=\${OLLAMA_BASE_URL:-http://host.docker.internal:11434}
      - ENABLE_OLLAMA_API=true
EOF
fi
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
      - DATABASE_URL=\${DATABASE_URL:-sqlite:////app/backend/data.sqlite}
EOF
fi
cat <<EOF
      - WEBUI_SECRET_KEY=\${WEBUI_SECRET_KEY:-changeme}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

if [ "$USE_OLLAMA" = "Y" ]; then
    cat <<EOF
  ollama:
    container_name: \${PROJECT_NAME:-open-webui}-ollama
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - \${PROJECT_NAME:-open-webui}-ollama-data:/root/.ollama
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
fi

if [ "$USE_PG" = "Y" ]; then
    cat <<'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-open-webui}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: openwebui
    volumes:
      - openwebui-pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
fi

cat <<EOF
volumes:
  ${PROJECT_NAME:-open-webui}-data:
EOF
if [ "$USE_OLLAMA" = "Y" ]; then
    echo "  ${PROJECT_NAME:-open-webui}-ollama-data:"
fi
if [ "$USE_PG" = "Y" ]; then
    echo "  openwebui-pgdata:"
fi

} > "$PROJECT_DIR/docker-compose.yml"

create_file "$PROJECT_DIR/start-all.sh" '#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Open WebUI services..."

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

$COMPOSE_CMD down 2>/dev/null || true
$COMPOSE_CMD up -d

echo -e "\033[0;32mOpen WebUI started!\033[0m"
echo -e "WebUI: \033[1;33mhttp://localhost:$WEBUI_PORT${WEBUI_PORT:-3000}\033[0m"
echo -e "Logs: \033[1;33m$COMPOSE_CMD logs -f\033[0m"
echo -e "Stop: \033[1;33m$COMPOSE_CMD down\033[0m"
'

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

echo "Stopping Open WebUI services..."
$COMPOSE_CMD down
echo "Services stopped!"
'

create_file "$PROJECT_DIR/.dockerignore" "# Data directories
data/
venv/

# Git
.git/

# IDE
.vscode/
.idea/

# OS
.DS_Store
*.md
"

create_file "$PROJECT_DIR/.gitignore" "# Environment
.env
*.sqlite

# Data
data/
venv/

# Git
.git/

# IDE
.vscode/
.idea/

# OS
.DS_Store
"

create_file "$PROJECT_DIR/README.md" "# $PROJECT_NAME

Open WebUI - Web Interface for LLMs

A user-friendly web interface for chat and document management with LLM integration.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- WebUI: http://localhost:${WEBUI_PORT:-3000}
- Default admin: admin@example.com

## Configuration

Edit \`.env\`:
- \`WEBUI_PORT\`: Web UI port
- \`OLLAMA_BASE_URL\`: Ollama API endpoint
- \`DATABASE_URL\`: Database connection
- \`WEBUI_SECRET_KEY\`: Application secret key

## Features

- Chat with LLMs (Ollama compatible)
- Document uploads with RAG
- Multi-user support
- OAuth authentication (optional)
- Streaming responses
- File and image support

## Services

- **WebUI**: Main web interface
- **Ollama**: [Optional] Local LLM inference engine
- **PostgreSQL**: [Optional] Database for persistent data
"

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Open WebUI project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${WEBUI_PORT:-3000}${NC}"
echo ""
