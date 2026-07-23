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

echo -e "${GREEN}Creating Docker Registry project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 5000]: ${NC}" REGISTRY_PORT
REGISTRY_PORT=${REGISTRY_PORT:-5000}

read -p "${CYAN}Use authentication? (y/N) [default: N]: ${NC}" USE_AUTH
USE_AUTH=${USE_AUTH^^}
USE_AUTH=${USE_AUTH:-N}

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
# Docker Registry Configuration
PROJECT_NAME=$PROJECT_NAME
REGISTRY_PORT=$REGISTRY_PORT
REGISTRY_STORAGE_DELETE=true
REGISTRY_HTTP_SECRET=change-me-to-secure-random-string

# Auth (optional)
EOF
if [ "$USE_AUTH" = "Y" ]; then
    cat <<EOF
REGISTRY_AUTH=htpasswd
REGISTRY_AUTH_HTPASSWD_REALM=Registry
REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd
REGISTRY_USERNAME=admin
REGISTRY_PASSWORD=changeme
EOF
fi
cat <<EOF

# HTTPS (optional)
EOF
if [ "$USE_HTTPS" = "Y" ]; then
    cat <<EOF
REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt
REGISTRY_HTTP_TLS_KEY=/certs/domain.key
REGISTRY_HOSTNAME=localhost
EOF
fi
cat <<EOF

# Storage
REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  registry:
    container_name: \${PROJECT_NAME:-registry}-app
    image: \${REGISTRY_IMAGE:-registry}:\${REGISTRY_VERSION:-2}
    ports:
      - "\${REGISTRY_PORT:-5000}:5000"
    volumes:
      - \${PROJECT_NAME:-registry}-data:/var/lib/registry
EOF
if [ "$USE_AUTH" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
      - ./auth:/auth
EOF
fi
cat >> "$PROJECT_DIR/docker-compose.yml" << EOF
    environment:
      REGISTRY_STORAGE_DELETE_ENABLED: "\${REGISTRY_STORAGE_DELETE:-true}"
      REGISTRY_HTTP_ADDR: 0.0.0.0:5000
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5000/v2/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

EOF

if [ "$USE_AUTH" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  registry-auth:
    container_name: ${PROJECT_NAME:-registry}-auth
    image: nginx:alpine
    ports:
      - "5001:80"
    volumes:
      - ./auth:/usr/share/nginx/html
    restart: unless-stopped
    command: nginx -g 'daemon off;'
EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-registry}-data:
EOF

cat > "$PROJECT_DIR/create-auth.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

USERNAME="${REGISTRY_USERNAME:-admin}"
PASSWORD="${REGISTRY_PASSWORD:-changeme}"

mkdir -p "$SCRIPT_DIR/auth"

echo "Creating htpasswd file..."
echo "$USERNAME:$$(htpasswd -nb "$USERNAME" "$PASSWORD" | cut -d: -f2)" > auth/htpasswd

echo -e "\033[0;32mAuth credentials created for user: $USERNAME\033[0m"
echo "Credentials: $USERNAME / $PASSWORD"
SCRIPT

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Docker Registry services..."

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

echo -e "\033[0;32mDocker Registry started!\033[0m"
echo -e "Registry: \033[1;33mhttp://localhost:$REGISTRY_PORT${REGISTRY_PORT:-5000}\033[0m"
echo -e "Test pull: docker pull localhost:$REGISTRY_PORT${REGISTRY_PORT:-5000}/"
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

echo "Stopping Docker Registry services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
auth/
certs/
.vscode/
.idea/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
auth/htpasswd
certs/
*.log
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Docker Registry

Self-hosted Docker image registry.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh create-auth.sh
./create-auth.sh   # Only if using auth
./start-all.sh
\`\`\`

## Access

- Registry: http://localhost:${REGISTRY_PORT:-5000}
- API: http://localhost:${REGISTRY_PORT:-5000}/v2/

## Usage

\`\`\`bash
# Tag and push image
docker tag myimage:latest localhost:${REGISTRY_PORT:-5000}/myimage:latest
docker push localhost:${REGISTRY_PORT:-5000}/myimage:latest

# Pull from registry
docker pull localhost:${REGISTRY_PORT:-5000}/myimage:latest
\`\`\`

## Configuration

Edit \`.env\`:
- \`REGISTRY_PORT\`: Registry port
- Authentication htpasswd file
- Certificate paths for HTTPS
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh" "$PROJECT_DIR/create-auth.sh"
mkdir -p "$PROJECT_DIR/auth" 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Docker Registry project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${REGISTRY_PORT:-5000}${NC}"
echo ""
