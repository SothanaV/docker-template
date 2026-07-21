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

echo -e "${GREEN}Creating n8n project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 5678]: ${NC}" N8N_PORT
N8N_PORT=${N8N_PORT:-5678}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: Y]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-Y}

read -p "${CYAN}Enable authentication? (y/N) [default: Y]: ${NC}" USE_AUTH
USE_AUTH=${USE_AUTH^^}
USE_AUTH=${USE_AUTH:-Y}

read -p "${CYAN}n8n version [default: latest]: ${NC}" N8N_VERSION
N8N_VERSION=${N8N_VERSION:-latest}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# n8n Configuration
PROJECT_NAME=$PROJECT_NAME
N8N_PORT=$N8N_PORT
N8N_VERSION=$N8N_VERSION

# n8n settings
N8N_HOST=localhost
N8N_PROTOCOL=http
N8N_SECURE_COOKIE=false

# Webhook URL
N8N_WEBHOOK_URL=http://localhost:$N8N_PORT

# Authentication
EOF
if [ "$USE_AUTH" = "Y" ]; then
    cat <<EOF
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=admin
EOF
fi
cat <<EOF

# PostgreSQL (default)
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=localhost
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=postgres
DB_POSTGRESDB_PASSWORD=postgres
DB_POSTGRESDB_SCHEMA=public
EOF
fi
cat <<EOF

# Secret key for encryption
N8N_ENCRYPTION_KEY=changeme-rotate-for-production
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  n8n:
    container_name: \${PROJECT_NAME:-n8n}-app
    image: \${N8N_IMAGE:-n8nio/n8n}:\${N8N_VERSION:-latest}
    ports:
      - "\${N8N_PORT:-5678}:5678"
    volumes:
      - \${PROJECT_NAME:-n8n}-data:/home/node/.n8n
    environment:
      - PORT=\${N8N_PORT:-5678}
      - N8N_HOST=\${N8N_HOST:-localhost}
      - N8N_PROTOCOL=\${N8N_PROTOCOL:-http}
      - N8N_SECURE_COOKIE=\${N8N_SECURE_COOKIE:-false}
      - N8N_WEBHOOK_URL=\${N8N_WEBHOOK_URL:-http://localhost:$N8N_PORT}
EOF
if [ "$USE_AUTH" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
      - N8N_BASIC_AUTH_ACTIVE=true
EOF
fi
if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=postgres
    depends_on:
      - postgres
EOF
fi
cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
EOF

if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-n8n}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: n8n
    volumes:
      - n8n-pgdata:/var/lib/postgresql/data
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
  ${PROJECT_NAME:-n8n}-data:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  n8n-pgdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting n8n services..."

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

echo -e "\033[0;32mn8n started!\033[0m"
echo -e "n8n UI: \033[1;33mhttp://localhost:$N8N_PORT${N8N_PORT:-5678}\033[0m"
echo -e "Webhook: \033[1;33m${N8N_WEBHOOK_URL:-http://localhost:$N8N_PORT}\033[0m"
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

echo "Stopping n8n services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
.n8n/
*.md
.env
.vscode/
.idea/
node_modules/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
.vscode/
.idea/
.DS_Store
node_modules/
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

n8n - Workflow Automation Platform

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- n8n UI: http://localhost:${N8N_PORT:-5678}
- Webhooks: http://localhost:${N8N_PORT:-5678}/webhook/

## Features

- 400+ integrations
- Visual workflow builder
- Custom nodes support
- Scheduled workflows
- API endpoints for webhooks

## Configuration

Edit \`.env\`:
- \`N8N_PORT\`: UI port
- \`N8N_WEBHOOK_URL\`: Public webhook URL
- Database credentials (if PostgreSQL)
- Auth settings
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}n8n project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${N8N_PORT:-5678}${NC}"
echo ""
