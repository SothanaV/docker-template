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

echo -e "${GREEN}Creating Valkey project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 6379]: ${NC}" VALKEY_PORT
VALKEY_PORT=${VALKEY_PORT:-6379}

read -p "${CYAN}Enable TLS? (y/N) [default: N]: ${NC}" USE_TLS
USE_TLS=${USE_TLS^^}
USE_TLS=${USE_TLS:-N}

read -p "${CYAN}Valkey version [default: latest]: ${NC}" VALKEY_VERSION
VALKEY_VERSION=${VALKEY_VERSION:-latest}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Valkey (Redis fork) Configuration
PROJECT_NAME=$PROJECT_NAME
VALKEY_PORT=$VALKEY_PORT
VALKEY_VERSION=$VALKEY_VERSION

# Authentication
VALKEY_PASSWORD=changeme

# Persistence
VALKEY_APPENDONLY=yes
VALKEY_MAXMEMORY=256mb
VALKEY_MAXMEMORY_POLICY=allkeys-lru

# TLS (optional)
EOF
if [ "$USE_TLS" = "Y" ]; then
    cat <<EOF
VALKEY_TLS_PORT=6380
VALKEY_TLS_CERT_FILE=/data/certs/server.crt
VALKEY_TLS_KEY_FILE=/data/certs/server.key
VALKEY_TLS_CA_CERT_FILE=/data/certs/ca.crt
EOF
fi
cat <<EOF

# Logging
VALKEY_LOGLEVEL=notice
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  valkey:
    container_name: \${PROJECT_NAME:-valkey}-app
    image: \${VALKEY_IMAGE:-valkey/valkey}:\${VALKEY_VERSION:-latest}
    ports:
      - "\${VALKEY_PORT:-6379}:6379"
    volumes:
      - \${PROJECT_NAME:-valkey}-data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

EOF

if [ "$USE_TLS" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" <<EOF
  valkey-tls:
    container_name: \${PROJECT_NAME:-valkey}-tls
    image: \${VALKEY_IMAGE:-valkey/valkey}:\${VALKEY_VERSION:-latest}
    ports:
      - "6380:6380"
    volumes:
      - \${PROJECT_NAME:-valkey}-data:/data
      - ./tls:/tls:ro
    environment:
      - VALKEY_TLS_PORT=6380
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "valkey-cli", "--tls", "--cert", "/tls/server.crt", "--key", "/tls/server.key", "--cacert", "/tls/ca.crt", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-valkey}-data:
EOF

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Valkey services..."

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

echo -e "\033[0;32mValkey started!\033[0m"
echo -e "Valkey: \033[1;33mlocalhost:$VALKEY_PORT${VALKEY_PORT:-6379}\033[0m"
echo -e "CLI: \033[1;33m$COMPOSE_CMD exec valkey valkey-cli\033[0m"
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

echo "Stopping Valkey services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
tls/
.vscode/
.idea/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
tls/
*.rdb
*.aof
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Valkey - Open Source Redis Fork

Valkey is a high-performance key-value store managed by the Linux Foundation.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- Port: ${VALKEY_PORT:-6379}
- Password: ${VALKEY_PASSWORD:-changeme}
- CLI: docker compose exec valkey valkey-cli -a changeme

## Configuration

Edit \`.env\`:
- \`VALKEY_PORT\`: Port number
- \`VALKEY_PASSWORD\`: Authentication password
- \`VALKEY_MAXMEMORY\`: Max memory limit
- \`VALKEY_APPENDONLY\`: Enable AOF persistence
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Valkey project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${VALKEY_PORT:-6379}${NC}"
echo ""
