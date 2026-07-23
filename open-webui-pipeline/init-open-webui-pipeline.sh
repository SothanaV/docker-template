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

echo -e "${GREEN}Creating Open WebUI Pipeline project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 3000]: ${NC}" WEBUI_PORT
WEBUI_PORT=${WEBUI_PORT:-3000}

read -p "${CYAN}Ollama URL [default: http://localhost:11434]: ${NC}" OLLAMA_URL
OLLAMA_URL=${OLLAMA_URL:-http://localhost:11434}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: N]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-N}

read -p "${CYAN}Pipeline URL [default: http://localhost:8090]: ${NC}" PIPELINE_URL
PIPELINE_URL=${PIPELINE_URL:-http://localhost:8090}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Open WebUI Pipeline Configuration
PROJECT_NAME=$PROJECT_NAME
WEBUI_PORT=$WEBUI_PORT

# Ollama Connection
OLLAMA_BASE_URL=$OLLAMA_URL

# Database (optional)
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

# Pipeline Configuration
PIPELINE_URL=$PIPELINE_URL
PIPELINE_ENABLED=true

# Secret
WEBUI_SECRET_KEY=changeme-to-something-secure

# Embeddings (optional)
EMBEDDINGS_MODEL=nomic-embed-text
EMBEDDINGS_BACKEND=text-embeddings-inference
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  webui:
    container_name: \${PROJECT_NAME:-openwebui-pipeline}-app
    image: ghcr.io/open-webui/open-webui:latest
    ports:
      - "\${WEBUI_PORT:-3000}:8080"
    volumes:
      - \${PROJECT_NAME:-openwebui-pipeline-data}:/app/backend/data
    environment:
      - WEBUI_PORT=8080
      - OLLAMA_BASE_URL=\${OLLAMA_BASE_URL:-http://host.docker.internal:11434}
      - ENABLE_OLLAMA_API=true
EOF
if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/openwebui
    depends_on:
      - postgres
EOF
fi
cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-changeme}
      - PIPELINE_URL=${PIPELINE_URL:-http://pipeline:8090}
      - PIPELINE_ENABLED=true
      - EMBEDDINGS_MODEL=${EMBEDDINGS_MODEL:-nomic-embed-text}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

EOF

if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-openwebui-pipeline}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: openwebui
    volumes:
      - openwebui-pipeline-pgdata:/var/lib/postgresql/data
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

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-openwebui-pipeline-data}:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  openwebui-pipeline-pgdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Open WebUI Pipeline services..."

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

echo -e "\033[0;32mOpen WebUI Pipeline started!\033[0m"
echo -e "WebUI: \033[1;33mhttp://localhost:$WEBUI_PORT${WEBUI_PORT:-3000}\033[0m"
echo -e "Pipeline: \033[1;33m${PIPELINE_URL:-http://localhost:8090}\033[0m"
echo -e "Logs: \033[1;33m$COMPOSE_CMD logs -f\033[0m"
echo -e "Stop: \033[1;33m$COMPOSE_CMD down\033[0m"
SCRIPT

cat > "$PROJECT_DIR/stop-all.sh" << 'SCRIPT'
#!/bin/bash
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

echo "Stopping Open WebUI Pipeline services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
data/
venv/
.git/
*.md
.env
.vscode/
.idea/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.sqlite
data/
venv/
__pycache__/
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Open WebUI Pipeline

Open WebUI with custom pipeline integration for extended AI capabilities.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

## Access

- WebUI: http://localhost:${WEBUI_PORT:-3000}
- Pipeline: ${PIPELINE_URL:-http://localhost:8090}
- Default admin: admin@example.com

## Configuration

Edit \`.env\`:
- \`WEBUI_PORT\`: Web UI port
- \`OLLAMA_BASE_URL\`: Ollama endpoint
- \`PIPELINE_URL\`: Pipeline service URL
- \`WEBUI_SECRET_KEY\`: Application secret

## What's a Pipeline?

Pipelines provide custom processing for AI requests:
- Custom prompt templates
- Response filtering
- Rate limiting
- Custom AI integrations
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Open WebUI Pipeline project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${WEBUI_PORT:-3000}${NC}"
echo ""
