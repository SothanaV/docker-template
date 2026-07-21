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

echo -e "${GREEN}Creating Cloud Beaver project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 5000]: ${NC}" BEAVER_PORT
BEAVER_PORT=${BEAVER_PORT:-5000}

read -p "${CYAN}Service name [default: cloudbeaver]: ${NC}" BEAVER_SERVICE
BEAVER_SERVICE=${BEAVER_SERVICE:-cloudbeaver}

read -p "${CYAN}Init timeout (seconds) [default: 300]: ${NC}" INIT_TIMEOUT
INIT_TIMEOUT=${INIT_TIMEOUT:-300}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# CloudBeaver Configuration
PROJECT_NAME=$PROJECT_NAME
BEAVER_PORT=$BEAVER_PORT
BEAVER_SERVICE=$BEAVER_SERVICE

# Server
CB_SERVER_PORT=8978

# Databases to pre-connect (optional, comma-separated)
# Examples: postgresql, mysql, mssql, oracle, snowflake
CB_PRECONNECT_DATABASES=

# Default credentials (for database connections)
# CB_PG_USER=postgres
# CB_PG_PASSWORD=postgres
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  cloudbeaver:
    container_name: \${PROJECT_NAME:-cloudbeaver}-app
    image: \${CLOUD_BEAVER_IMAGE:-ghcr.io/dbeaver/cloudbeaver}:\${CLOUD_BEAVER_VERSION:-latest}
    ports:
      - "\${BEAVER_PORT:-5000}:\${BEAVER_PORT:-5000}"
    volumes:
      - \${PROJECT_NAME:-cloudbeaver}-workspace:/opt/cloudbeaver/workspaces
      - \${PROJECT_NAME:-cloudbeaver}-data:/opt/cloudbeaver/data
    environment:
      CB_SERVER_PORT: \${CB_SERVER_PORT:-8978}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8978/api/v1/configuration/info"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: \${INIT_TIMEOUT:-300}s

EOF

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-cloudbeaver}-workspace:
  ${PROJECT_NAME:-cloudbeaver}-data:
EOF

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting CloudBeaver services..."
echo "First run may take a few minutes for initialization..."

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

echo -e "\033[0;32mCloudBeaver started!\033[0m"
echo -e "UI: \033[1;33mhttp://localhost:$BEAVER_PORT${BEAVER_PORT:-5000}\033[0m"
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

echo "Stopping CloudBeaver services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
.vscode/
.idea/
node_modules/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
.vscode/
.idea/
.DS_Store
node_modules/
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

CloudBeaver - Cloud Database IDE

Powered by DBeaver. Access databases from your browser.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

First initialization may take 2-5 minutes.

## Access

- UI: http://localhost:${BEAVER_PORT:-5000}

## Supported Databases

- PostgreSQL
- MySQL / MariaDB
- SQL Server
- Oracle
- Snowflake
- SQLite
- And more via JDBC drivers

## Configuration

Edit \`.env\`:
- \`BEAVER_PORT\`: UI port
- \`CB_SERVER_PORT\`: Internal server port
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CloudBeaver project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${BEAVER_PORT:-5000}${NC}"
echo ""
