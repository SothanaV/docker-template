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

echo -e "${GREEN}Creating OWASP ZAP project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 8080]: ${NC}" ZAP_PORT
ZAP_PORT=${ZAP_PORT:-8080}

read -p "${CYAN}Use daemon mode? (y/N) [default: Y]: ${NC}" USE_DAEMON
USE_DAEMON=${USE_DAEMON^^}
USE_DAEMON=${USE_DAEMON:-Y}

read -p "${CYAN}Add WebSocket port? (y/N) [default: N]: ${NC}" USE_WEBSOCKET
USE_WEBSOCKET=${USE_WEBSOCKET^^}
USE_WEBSOCKET=${USE_WEBSOCKET:-N}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# OWASP ZAP Configuration
PROJECT_NAME=$PROJECT_NAME
ZAP_PORT=$ZAP_PORT
ZAP_VERSION=stable

# Server
ZAP_SERVER_PORT=$ZAP_PORT
ZAP_API_KEY=changeme-change-this-key
ZAP_BIND_ADDRESS=0.0.0.0

# Scan settings
ZAP_ADDONS=ALL

# WebSocket (optional)
EOF
if [ "$USE_WEBSOCKET" = "Y" ]; then
    cat >> "$PROJECT_DIR/.env" << EOF
ZAP_WS_PORT=$((ZAP_PORT + 1))
EOF
fi
cat >> "$PROJECT_DIR/.env" << 'EOF'

# Logging
ZAP_LOG_LEVEL=INFO
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  zaproxy:
    container_name: \${PROJECT_NAME:-zap}-app
    image: \${ZAP_IMAGE:-ghcr.io/zaproxy/zaproxy}:\${ZAP_VERSION:-stable}
    ports:
      - "\${ZAP_PORT:-8080}:8080"
    volumes:
      - \${PROJECT_NAME:-zap}-data:/home/zap/.owasp/zap2docker-stable
      - \${PROJECT_NAME:-zap}-scripts:/home/zap/zap-scripts
    environment:
      ZAP_PORT: \${ZAP_PORT:-8080}
      ZAP_API_KEY: \${ZAP_API_KEY:-changeme}
      ZAP_ADDONS: \${ZAP_ADDONS:-ALL}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/JSON/core/view/about/?apikey=\${ZAP_API_KEY:-changeme}"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

EOF

if [ "$USE_WEBSOCKET" = "Y" ]; then
    ZAP_WS_PORT=$((ZAP_PORT + 1))
    cat >> "$PROJECT_DIR/docker-compose.yml" << EOF
  zaproxy-ws:
    container_name: \${PROJECT_NAME:-zap}-ws
    image: \${ZAP_IMAGE:-ghcr.io/zaproxy/zaproxy}:\${ZAP_VERSION:-stable}
    expose:
      - "6060"
    environment:
      ZAP_PORT: 6060
      ZAP_API_KEY: \${ZAP_API_KEY:-changeme}
    command: ["bin/zap.sh", "-cmd", "-port", "6060", "-config", "api.key=\${ZAP_API_KEY:-changeme}"]
    restart: unless-stopped

EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-zap}-data:
  ${PROJECT_NAME:-zap}-scripts:
EOF

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting ZAP services..."

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

echo -e "\033[0;32mOWASP ZAP started!\033[0m"
echo -e "ZAP UI: \033[1;33mhttp://localhost:$ZAP_PORT${ZAP_PORT:-8080}\033[0m"
echo -e "API: \033[1;33mhttp://localhost:$ZAP_PORT${ZAP_PORT:-8080}/CORE/VIEW/ABOUT/?apikey=changeme\033[0m"
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

echo "Stopping ZAP services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/scan-target.sh" << 'SCRIPT'
#!/bin/bash
set -e

TARGET_URL="${1:-http://localhost:8080}"
echo "Starting ZAP scan against: $TARGET_URL"

# Full smoke and pass scan
curl -X POST "http://localhost:8080/JSON/ascan/scanner/scan/?apikey=changeme&url=$TARGET_URL"

echo -e "\033[0;32mScan started for: $TARGET_URL\033[0m"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
.vscode/
.idea/
zap/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
*.log.*
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

OWASP ZAP - Web Security Scanner

Zed Attack Proxy - Find vulnerabilities in web applications.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh scan-target.sh
./start-all.sh
\`\`\`

ZAP takes a few minutes to fully initialize.

## Access

- ZAP UI: http://localhost:${ZAP_PORT:-8080}
- API Key: changeme (change in .env)

## Usage

\`\`\`bash
# Scan a target
./scan-target.sh http://target-to-scan.com

# Full scan via API
curl "http://localhost:${ZAP_PORT:-8080}/OTHER/core/other/spider/?apikey=changeme&apikey=changeme&target=http://target-to-scan.com"
\`\`\`

## Configuration

Edit \`.env\`:
- \`ZAP_PORT\`: Web UI port
- \`ZAP_API_KEY\`: API key for REST API
- \`ZAP_ADDONS\`: Addons to install
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh" "$PROJECT_DIR/scan-target.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OWASP ZAP project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${ZAP_PORT:-8080}${NC}"
echo ""
