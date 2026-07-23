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

echo -e "${GREEN}Creating Flowise project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 3000]: ${NC}" FLOWISE_PORT
FLOWISE_PORT=${FLOWISE_PORT:-3000}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: N]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-N}

read -p "${CYAN}Enable API authentication? (y/N) [default: N]: ${NC}" USE_AUTH
USE_AUTH=${USE_AUTH^^}
USE_AUTH=${USE_AUTH:-N}

read -p "${CYAN}Flowise version [default: latest]: ${NC}" FLOWISE_VERSION
FLOWISE_VERSION=${FLOWISE_VERSION:-latest}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

{
cat <<EOF
# Flowise Environment Configuration
PROJECT_NAME=$PROJECT_NAME
FLOWISE_PORT=$FLOWISE_PORT
FLOWISE_VERSION=$FLOWISE_VERSION

# Server settings
FLOWISE_DEBUG=false
FLOWISE_FILE_SIZE_LIMIT=50

# API Config (optional)
EOF
if [ "$USE_AUTH" = "Y" ]; then
    cat <<EOF
BUILT_IN_CREDENTIALS_DECRYPT_KEY=change-me-to-something-random
APIKEY_SECRET_KEY=change-me-to-something-random
EOF
fi
cat <<EOF

# Database settings
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/flowise
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=flowise
EOF
else
    cat <<EOF
# Using SQLite (default)
DATA_DIR=./data
EOF
fi
cat <<EOF

# Credentials encryption
EOF
if [ "$USE_AUTH" = "Y" ]; then
    echo "BUILT_IN_CREDENTIALS_DECRYPT_KEY=change-me-to-something-random"
fi
EOF
} > "$PROJECT_DIR/.env"

{
cat <<EOF
services:
  flowise:
    container_name: \${PROJECT_NAME:-flowise}-app
    image: \${FLOWISE_IMAGE:-flowiseai/flowise}:\${FLOWISE_VERSION:-latest}
    ports:
      - "\${FLOWISE_PORT:-3000}:3000"
    volumes:
      - \${PROJECT_NAME:-flowise}-data:/home/node/.flowise
    environment:
      - PORT=\${FLOWISE_PORT:-3000}
      - FLOWISE_DEBUG=\${FLOWISE_DEBUG:-false}
      - FLOWISE_FILE_SIZE_LIMIT=\${FLOWISE_FILE_SIZE_LIMIT:-50}
EOF
if [ "$USE_AUTH" = "Y" ]; then
    cat <<EOF
      - BUILT_IN_CREDENTIALS_DECRYPT_KEY=\${BUILT_IN_CREDENTIALS_DECRYPT_KEY:-change-me}
      - APIKEY_SECRET_KEY=\${APIKEY_SECRET_KEY:-change-me}
EOF
fi
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
      - DATABASE_URL=\${DATABASE_URL:-postgresql://postgres:postgres@postgres:5432/flowise}
EOF
fi
cat <<EOF
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "node", "--eval", "require('http').get('http://localhost:3000/api/v1/ping', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

if [ "$USE_PG" = "Y" ]; then
    cat <<'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-flowise}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: flowise
    volumes:
      - flowise-pgdata:/var/lib/postgresql/data
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
  ${PROJECT_NAME:-flowise}-data:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  flowise-pgdata:"
fi

} > "$PROJECT_DIR/docker-compose.yml"

create_file "$PROJECT_DIR/start-all.sh" '#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Flowise services..."

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

echo -e "\033[0;32mFlowise started!\033[0m"
echo -e "Flowise UI: \033[1;33mhttp://localhost:$FLOWISE_PORT${FLOWISE_PORT:-3000}\033[0m"
echo -e "API: \033[1;33mhttp://localhost:$FLOWISE_PORT${FLOWISE_PORT:-3000}/api/v1/\033[0m"
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

echo "Stopping Flowise services..."
$COMPOSE_CMD down
echo "Services stopped!"
'

create_file "$PROJECT_DIR/.dockerignore" "# Node
node_modules/
npm-debug.log*
yarn-debug.log*

# Env
.env

# Git
.git/

# IDE
.vscode/
.idea/

# OS
.DS_Store
*.md
"

create_file "$PROJECT_DIR/.gitignore" ".env
node_modules/
.env.*
*.log
.vscode/
.idea/
.DS_Store
"

create_file "$PROJECT_DIR/README.md" "# $PROJECT_NAME

Flowise - Flow/Chains Builder for AI

Build LLM applications with a visual drag-and-drop interface.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- Flowise UI: http://localhost:${FLOWISE_PORT:-3000}
- API: http://localhost:${FLOWISE_PORT:-3000}/api/v1/

## Features

- Visual workflow builder
- Pre-built AI components
- Multi-chat integration
- Chat history and memory
- API access for integrations

## Configuration

Edit \`.env\`:
- \`FLOWISE_PORT\`: UI port
- \`DATABASE_URL\`: PostgreSQL connection
- \`BUILT_IN_CREDENTIALS_DECRYPT_KEY\`: Encryption key

## Volumes

- Flows and data: \${PROJECT_NAME}-data
- PostgreSQL (if using): flowise-pgdata
"

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Flowise project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${FLOWISE_PORT:-3000}${NC}"
echo ""
