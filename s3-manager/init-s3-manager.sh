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

echo -e "${GREEN}Creating S3 Manager project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 9001]: ${NC}" S3M_PORT
S3M_PORT=${S3M_PORT:-9001}

read -p "${CYAN}MinIO endpoint [default: http://localhost:9000]: ${NC}" S3M_ENDPOINT
S3M_ENDPOINT=${S3M_ENDPOINT:-http://localhost:9000}

read -p "${CYAN}MinIO Access Key [default: minioadmin]: ${NC}" S3M_ACCESS_KEY
S3M_ACCESS_KEY=${S3M_ACCESS_KEY:-minioadmin}

read -p "${CYAN}MinIO Secret Key [default: minioadmin]: ${NC}" S3M_SECRET_KEY
S3M_SECRET_KEY=${S3M_SECRET_KEY:-minioadmin}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# S3 Manager Configuration
PROJECT_NAME=$PROJECT_NAME
S3M_PORT=$S3M_PORT

# MinIO / S3 settings
S3M_ENDPOINT=$S3M_ENDPOINT
S3M_ACCESS_KEY=$S3M_ACCESS_KEY
S3M_SECRET_KEY=$S3M_SECRET_KEY

# UI Settings
S3M_DEFAULT_BUCKET=uploads
S3M_ALLOW_DELETE=true
S3M_ALLOW_CREATE_BUCKET=true

# Auth (optional)
S3M_USERNAME=admin
S3M_PASSWORD=admin
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  s3-manager:
    container_name: \${PROJECT_NAME:-s3-manager}-app
    image: \${S3M_IMAGE:-l3x/s3fs-webdav-minio}:\${S3M_VERSION:-latest}
    ports:
      - "\${S3M_PORT:-9001}:9001"
    environment:
      - S3_ENDPOINT=\${S3M_ENDPOINT:-http://localhost:9000}
      - S3_ACCESS_KEY=\${S3M_ACCESS_KEY:-minioadmin}
      - S3_SECRET_KEY=\${S3M_SECRET_KEY:-minioadmin}
      - S3_PROTOCOL=https\${S3M_PROTOCOL:-true}
      - ALLOW_DELETE=\${S3M_ALLOW_DELETE:-true}
      - ALLOW_CREATE_BUCKET=\${S3M_ALLOW_CREATE_BUCKET:-true}
      - DEFAULT_BUCKET=\${S3M_DEFAULT_BUCKET:-uploads}
      - ADMIN_USERNAME=\${S3M_USERNAME:-admin}
      - ADMIN_PASSWORD=\${S3M_PASSWORD:-admin}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s

EOF

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-s3-manager}-data:
EOF

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting S3 Manager services..."

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

echo -e "\033[0;32mS3 Manager started!\033[0m"
echo -e "S3 Manager UI: \033[1;33mhttp://localhost:$S3M_PORT${S3M_PORT:-9001}\033[0m"
echo -e "MinIO: \033[1;33m${S3M_ENDPOINT:-http://localhost:9000}\033[0m"
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

echo "Stopping S3 Manager services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
.vscode/
.idea/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

S3 File Manager

Web-based file manager for S3-compatible storage (MinIO, AWS S3, etc.).

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

## Access

- UI: http://localhost:${S3M_PORT:-9001}

## Configuration

Edit \`.env\`:
- \`S3M_PORT\`: UI port
- \`S3M_ENDPOINT\`: MinIO/S3 API endpoint
- \`S3M_ACCESS_KEY\`: MinIO access key
- \`S3M_SECRET_KEY\`: MinIO secret key
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}S3 Manager project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${S3M_PORT:-9001}${NC}"
echo ""
