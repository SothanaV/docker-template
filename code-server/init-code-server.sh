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

echo -e "${GREEN}Creating Code-Server project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 8443]: ${NC}" CODESERVER_PORT
CODESERVER_PORT=${CODESERVER_PORT:-8443}

read -p "${CYAN}Password [default: changeme]: ${NC}" CODESERVER_PASSWORD
CODESERVER_PASSWORD=${CODESERVER_PASSWORD:-changeme}

read -p "${CYAN}User [default: code]: ${NC}" CODESERVER_USER
CODESERVER_USER=${CODESERVER_USER:-code}

read -p "${CYAN}Use HTTPS? (y/N) [default: N]: ${NC}" USE_HTTPS
USE_HTTPS=${USE_HTTPS^^}
USE_HTTPS=${USE_HTTPS:-N}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Code-Server Configuration
PROJECT_NAME=$PROJECT_NAME
CODESERVER_PORT=$CODESERVER_PORT
CODESERVER_PASSWORD=$CODESERVER_PASSWORD
CODESERVER_USER=$CODESERVER_USER
USE_HTTPS=$USE_HTTPS

# Settings
CODESERVER_WORKSPACE=/home/${CODESERVER_USER:-code}/project
VSCODE_VERSION=latest
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  code-server:
    container_name: \${PROJECT_NAME:-code-server}-app
    image: \${CODESERVER_IMAGE:-codercom/code-server}:\${VSCODE_VERSION:-latest}
    ports:
      - "\${CODESERVER_PORT:-8443}:8443"
    volumes:
      - \${PROJECT_NAME:-code-server}-data:/home/\${CODESERVER_USER:-code}
      - \${PROJECT_NAME:-code-server}-workspace:/home/\${CODESERVER_USER:-code}/project
    environment:
      - PASSWORD=\${CODESERVER_PASSWORD:-changeme}
      - USER=\${CODESERVER_USER:-code}
      - PROXY_DOMAIN=localhost:\${CODESERVER_PORT:-8443}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8443/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
EOF

if [ "$USE_HTTPS" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" <<EOF
    environment:
      - PASSWORD=\${CODESERVER_PASSWORD:-changeme}
      - USER=\${CODESERVER_USER:-code}
      - CS_DEVELOPMENT=false
      - HTTPS=true
EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-code-server}-data:
  ${PROJECT_NAME:-code-server}-workspace:
EOF

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Code-Server services..."

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

echo -e "\033[0;32mCode-Server started!\033[0m"
echo -e "VS Code Web: \033[1;33mhttp://localhost:$CODESERVER_PORT${CODESERVER_PORT:-8443}\033[0m"
if [ "$USE_HTTPS" = "Y" ]; then
    echo -e "HTTPS: \033[1;33mhttps://localhost:$CODESERVER_PORT${CODESERVER_PORT:-8443}\033[0m"
fi
echo -e "Password: \033[1;33m${CODESERVER_PASSWORD:-changeme}\033[0m"
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

echo "Stopping Code-Server services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
vscode/
node_modules/
*.md
.env
.vscode/
.idea/
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

Code-Server - VS Code in Browser

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- VS Code Web: http://localhost:${CODESERVER_PORT:-8443}
- Password: ${CODESERVER_PASSWORD:-changeme}

## Configuration

Edit \`.env\`:
- \`CODESERVER_PORT\`: Port number
- \`CODESERVER_PASSWORD\`: Login password
- \`CODESERVER_USER\`: Username
- \`CODESERVER_WORKSPACE\`: Workspace directory
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Code-Server project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${CODESERVER_PORT:-8443}${NC}"
echo ""
