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

echo -e "${GREEN}Creating Langflow project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

# Interactive menu
read -p "${CYAN}Enter Langflow port [default: 7860]: ${NC}" LANGFLOW_PORT
LANGFLOW_PORT=${LANGFLOW_PORT:-7860}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: N]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-N}

read -p "${CYAN}Use Redis for caching? (y/N) [default: N]: ${NC}" USE_REDIS
USE_REDIS=${USE_REDIS^^}
USE_REDIS=${USE_REDIS:-N}

read -p "${CYAN}Use Qdrant vector store? (y/N) [default: N]: ${NC}" USE_QDRANT
USE_QDRANT=${USE_QDRANT^^}
USE_QDRANT=${USE_QDRANT:-N}

read -p "${CYAN}Langflow version [default: latest]: ${NC}" LANGFLOW_VERSION
LANGFLOW_VERSION=${LANGFLOW_VERSION:-latest}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

# .env
{
cat <<EOF
# Langflow Environment Configuration
PROJECT_NAME=$PROJECT_NAME
LANGFLOW_PORT=$LANGFLOW_PORT
LANGFLOW_VERSION=$LANGFLOW_VERSION

# Langflow settings
LANGFLOW_AUTO_LOGIN=false
LANGFLOW_SUPERUSER=admin
LANGFLOW_SUPERUSER_PASSWORD=changeme

# PostgreSQL (optional)
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
LANGFLOW_DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/langflow
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=langflow
EOF
fi
cat <<EOF
# Redis (optional)
EOF
if [ "$USE_REDIS" = "Y" ]; then
    cat <<EOF
LANGFLOW_REDIS_URL=redis://localhost:6379/0
REDIS_HOST=localhost
REDIS_PORT=6379
EOF
fi
cat <<EOF
# Qdrant (optional)
EOF
if [ "$USE_QDRANT" = "Y" ]; then
    cat <<EOF
LANGFLOW_VECTOR_STORE_URL=http://localhost:6333
QDRANT_HOST=localhost
QDRANT_PORT=6333
EOF
fi
cat <<EOF
# Logging
LANGFLOW_LOG_LEVEL=info
EOF
} > "$PROJECT_DIR/.env"

# docker-compose.yml
{
cat <<'YAML'
services:
  langflow:
    container_name: ${PROJECT_NAME:-langflow}-app
    image: ${LANGFLOW_IMAGE:-langflowai/langflow}:${LANGFLOW_VERSION:-latest}
    ports:
      - "${LANGFLOW_PORT:-7860}:7860"
    volumes:
      - ${PROJECT_NAME:-langflow}-data:/app/langflow
    environment:
      - LANGFLOW_AUTO_LOGIN=${LANGFLOW_AUTO_LOGIN:-false}
      - LANGFLOW_SUPERUSER=${LANGFLOW_SUPERUSER:-admin}
      - LANGFLOW_SUPERUSER_PASSWORD=${LANGFLOW_SUPERUSER_PASSWORD:-changeme}
      - LANGFLOW_DATABASE_URL=${LANGFLOW_DATABASE_URL:-sqlite:////app/langflow/.local/share/langflow/db.sqlite3}
      - LANGFLOW_LOG_LEVEL=${LANGFLOW_LOG_LEVEL:-info}
      - LANGFLOW_SECRET_KEY=${LANGFLOW_SECRET_KEY:-changeme}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7860/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
YAML

if [ "$USE_PG" = "Y" ]; then
    cat <<'YAML'
  postgres:
    container_name: ${PROJECT_NAME:-langflow}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER:-postgres}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-postgres}
      POSTGRES_DB: ${DB_NAME:-langflow}
    volumes:
      - ${PROJECT_NAME:-langflow}-pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
YAML
fi

if [ "$USE_REDIS" = "Y" ]; then
    cat <<'YAML'
  redis:
    container_name: ${PROJECT_NAME:-langflow}-redis
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - ${PROJECT_NAME:-langflow}-redisdata:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
YAML
fi

if [ "$USE_QDRANT" = "Y" ]; then
    cat <<'YAML'
  qdrant:
    container_name: ${PROJECT_NAME:-langflow}-qdrant
    image: qdrant/qdrant:latest
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - ${PROJECT_NAME:-langflow}-qdrantdata:/qdrant/storage
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/health"]
      interval: 30s
      timeout: 10s
      retries: 3
YAML
fi

cat <<'YAML'
volumes:
YAML

if [ "$USE_PG" = "Y" ]; then
    echo "  ${PROJECT_NAME:-langflow}-pgdata:"
fi
if [ "$USE_REDIS" = "Y" ]; then
    echo "  ${PROJECT_NAME:-langflow}-redisdata:"
fi
if [ "$USE_QDRANT" = "Y" ]; then
    echo "  ${PROJECT_NAME:-langflow}-qdrantdata:"
fi
echo "  ${PROJECT_NAME:-langflow}-data:"

} > "$PROJECT_DIR/docker-compose.yml"

# start-all.sh
create_file "$PROJECT_DIR/start-all.sh" '#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Langflow services..."

if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed or not in PATH"
    exit 1
fi

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "Error: docker-compose is not installed"
    exit 1
fi

echo "Using: $COMPOSE_CMD"
$COMPOSE_CMD down 2>/dev/null || true
$COMPOSE_CMD up --build -d

echo ""
echo -e "\033[0;32mServices started successfully!\033[0m"
echo -e "Langflow UI: \033[1;33mhttp://localhost:$LANGFLOW_PORT${LANGFLOW_PORT:-7860}\033[0m"
echo -e "View logs: \033[1;33m$COMPOSE_CMD logs -f\033[0m"
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
    echo "Error: docker-compose is not installed"
    exit 1
fi

echo "Stopping Langflow services..."
$COMPOSE_CMD down

echo "Services stopped!"
'

# .dockerignore
create_file "$PROJECT_DIR/.dockerignore" "# Environment
.env
*.env

# Git
.git/
.gitignore

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Docker
docker-compose.override.yml

# Documentation
*.md
LICENSE
"

# .gitignore
create_file "$PROJECT_DIR/.gitignore" "# Environment
.env
*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Data volumes (if mounted locally)
*data/

# Logs
*.log
logs/"

# README.md
create_file "$PROJECT_DIR/README.md" "# $PROJECT_NAME

Langflow - AI LLM Flow Builder

## Prerequisites

- Docker
- Docker Compose

## Quick Start

### Start services
\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

### Stop services
\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- Langflow UI: http://localhost:${LANGFLOW_PORT:-7860}
- Default credentials: admin / changeme

## Configuration

Edit the \`.env\` file to configure:
- Database (PostgreSQL or SQLite default)
- Redis caching
- Qdrant vector store
- Admin credentials

### Optional Services

- **PostgreSQL**: Persistent storage for flows and data
- **Redis**: Caching and session management
- **Qdrant**: Vector database for embeddings and RAG

## Volume Mounts

All data is persisted in Docker volumes for reliability and easy backups.

## Usage

\`\`\`bash
# Build and start
docker compose up --build -d

# View logs
docker compose logs -f

# Scale services
docker compose up --build -d --scale langflow=2

# Stop and remove containers
docker compose down

# Stop and remove volumes (warn: deletes all data)
docker compose down -v
\`\`\`
"

# Make scripts executable
chmod +x "$PROJECT_DIR/start-all.sh"
chmod +x "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Langflow project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-all.sh stop-all.sh"
echo "3. ./start-all.sh"
echo "4. Open http://localhost:${LANGFLOW_PORT:-7860}"
echo ""
