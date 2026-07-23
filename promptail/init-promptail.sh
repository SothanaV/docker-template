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

echo -e "${GREEN}Creating Promptail project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 8000]: ${NC}" PROMPTAIL_PORT
PROMPTAIL_PORT=${PROMPTAIL_PORT:-8000}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: Y]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-Y}

read -p "${CYAN}Enable authentication? (y/N) [default: Y]: ${NC}" USE_AUTH
USE_AUTH=${USE_AUTH^^}
USE_AUTH=${USE_AUTH:-Y}

read -p "${CYAN}Enable versioning for prompts? (y/N) [default: Y]: ${NC}" USE_VERSIONING
USE_VERSIONING=${USE_VERSIONING^^}
USE_VERSIONING=${USE_VERSIONING:-Y}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

{
cat <<EOF
# Promptail Environment Configuration
PROJECT_NAME=$PROJECT_NAME
PROMPTAIL_PORT=$PROMPTAIL_PORT

# PostgreSQL
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/promptail
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=promptail
EOF
fi
cat <<EOF

# Authentication
EOF
if [ "$USE_AUTH" = "Y" ]; then
    cat <<EOF
SECRET_KEY=changeme-change-in-production
AUTH_ENABLED=true
TOKEN_EXPIRE_DAYS=7
ADMIN_EMAIL=admin@example.com
EOF
fi
cat <<EOF

# Versioning
VARIABLES_VERSIONING=$USE_VERSIONING

# Logging
LOG_LEVEL=info
EOF
} > "$PROJECT_DIR/.env"

{
cat <<EOF
services:
  promptail:
    container_name: \${PROJECT_NAME:-promptail}-app
    image: python:3.12-slim
    ports:
      - "\${PROMPTAIL_PORT:-8000}:8000"
    volumes:
      - ./app:/app
      - promptail-data:/app/data
      - promptail-logs:/app/logs
    environment:
      - DATABASE_URL=\${DATABASE_URL:-postgresql+asyncpg://postgres:postgres@postgres:5432/promptail}
      - AUTH_ENABLED=\${AUTH_ENABLED:-true}
      - SECRET_KEY=\${SECRET_KEY:-changeme}
      - LOG_LEVEL=\${LOG_LEVEL:-info}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
EOF

if [ "$USE_PG" = "Y" ]; then
    cat <<'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-promptail}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: promptail
    volumes:
      - promptail-pgdata:/var/lib/postgresql/data
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

cat <<'EOF'
volumes:
  promptail-data:
  promptail-logs:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  promptail-pgdata:"
fi

} > "$PROJECT_DIR/docker-compose.yml"

create_file "$PROJECT_DIR/app/Dockerfile" "FROM python:3.12-slim

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s \\
    CMD curl -f http://localhost:8000/health || exit 1

CMD [\"uvicorn\", \"main:app\", \"--host\", \"0.0.0.0\", \"--port\", \"8000\"]
"

create_file "$PROJECT_DIR/app/main.py" "from fastapi import FastAPI
from contextlib import asynccontextmanager

app = FastAPI(title=\"Promptail\")

@asynccontextmanager
async def lifespan(application: FastAPI):
    print(\"Promptail started!\")
    yield
    print(\"Promptail stopped!\")

app.router.lifespan_context = lifespan

@app.get(\"/health\")
async def health():
    return {\"status\": \"healthy\", \"service\": \"promptail\"}

@app.get(\"/\")
async def root():
    return {\"message\": \"Welcome to Promptail\", \"service\": \"prompt management\"}
"

create_file "$PROJECT_DIR/app/requirements.txt" "fastapi>=0.111.0
uvicorn[standard]>=0.29.0
sqlalchemy>=2.0.0
asyncpg>=0.29.0
pydantic>=2.7.0
python-multipart>=0.0.6
python-dotenv>=1.0.0
alembic>=1.13.0
"

create_file "$PROJECT_DIR/start-all.sh" '#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Promptail services..."

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
$COMPOSE_CMD up --build -d

echo -e "\033[0;32mPromptail started!\033[0m"
echo -e "UI: \033[1;33mhttp://localhost:$PROMPTAIL_PORT${PROMPTAIL_PORT:-8000}\033[0m"
echo -e "API: \033[1;33mhttp://localhost:$PROMPTAIL_PORT${PROMPTAIL_PORT:-8000}/docs\033[0m"
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

echo "Stopping Promptail services..."
$COMPOSE_CMD down
echo "Services stopped!"
'

create_file "$PROJECT_DIR/.dockerignore" "__pycache__/
*.py[cod]
.venv/
venv/
.env
*.egg-info/

.git/
.vscode/
.idea/
.DS_Store
*.md
"

create_file "$PROJECT_DIR/.gitignore" "__pycache__/
*.egg-info/
.env
.env.*
.vscode/
.idea/
.DS_Store
*.log
"

create_file "$PROJECT_DIR/README.md" "# $PROJECT_NAME

Promptail - Prompt Management Platform

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- UI/API: http://localhost:${PROMPTAIL_PORT:-8000}
- API Docs: http://localhost:${PROMPTAIL_PORT:-8000}/docs

## Features

- Prompt versioning and management
- Authentication (optional)
- PostgreSQL database for persistence
- Prompt history and rollback

## Configuration

Edit \`.env\` to set:
- \`PROMPTAIL_PORT\`: Server port
- Database credentials
- Authentication settings
- Logging level
"

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Promptail project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${PROMPTAIL_PORT:-8000}${NC}"
echo ""
