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

echo -e "${GREEN}Creating Databaseus project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 8090]: ${NC}" DATABASUS_PORT
DATABASUS_PORT=${DATABASUS_PORT:-8090}

read -p "${CYAN}Admin password [default: admin]: ${NC}" DB_USER_PASS
DB_USER_PASS=${DB_USER_PASS:-admin}

read -p "${CYAN}Enable user registration? (y/N) [default: N]: ${NC}" ENABLE_REG
ENABLE_REG=${ENABLE_REG^^}
ENABLE_REG=${ENABLE_REG:-N}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Databaseus Configuration
PROJECT_NAME=$PROJECT_NAME
DATABASUS_PORT=$DATABASUS_PORT
DB_USER_PASS=$DB_USER_PASS

# Server
DATABUS_HOST=0.0.0.0
DATABUS_PORT=$DATABASUS_PORT

# Database
DB_TYPE=sqlite
DB_URL=/app/data/databasus.db

# Auth
ENABLE_REGISTRATION=$ENABLE_REG
DATABUS_SESSION_SECRET=changeme-rotate-for-production

# Logging
LOG_LEVEL=info
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  databasus:
    container_name: \${PROJECT_NAME:-databasus}-app
    image: \${DATABASUS_IMAGE:-ghcr.io/databasus-io/databasus}:\${DATABASUS_VERSION:-latest}
    ports:
      - "\${DATABASUS_PORT:-8090}:8090"
    volumes:
      - \${PROJECT_NAME:-databasus}-data:/app/data
    environment:
      - DATABUS_PORT=8090
      - DATABUS_HOST=0.0.0.0
      - DB_TYPE=sqlite
      - DB_URL=/app/data/databasus.db
      - SESSION_SECRET=\${DATABUS_SESSION_SECRET:-changeme}
      - ENABLE_REGISTRATION=\${ENABLE_REGISTRATION:-false}
      - LOG_LEVEL=\${LOG_LEVEL:-info}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8090/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

volumes:
  ${PROJECT_NAME:-databasus}-data:
EOF

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Databaseus services..."

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

echo -e "\033[0;32mDatabaseus started!\033[0m"
echo -e "Databaseus UI: \033[1;33mhttp://localhost:$DATABASUS_PORT${DATABASUS_PORT:-8090}\033[0m"
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

echo "Stopping Databaseus services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
.vscode/
.idea/
data/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
data/
*.log
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Databaseus - Data Management Platform

A platform for managing and exploring databases.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

## Access

- UI: http://localhost:${DATABASUS_PORT:-8090}

## Configuration

Edit \`.env\`:
- \`DATABASUS_PORT\`: UI port
- \`DB_TYPE\`: Database backend (sqlite, postgresql)
- \`ENABLE_REGISTRATION\`: Allow user registration
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Databaseus project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${DATABASUS_PORT:-8090}${NC}"
echo ""
