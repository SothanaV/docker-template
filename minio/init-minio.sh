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

echo -e "${GREEN}Creating MinIO project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}S3 API Port [default: 9000]: ${NC}" MINIO_API_PORT
MINIO_API_PORT=${MINIO_API_PORT:-9000}

read -p "${CYAN}Console Port [default: 9001]: ${NC}" MINIO_CONSOLE_PORT
MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT:-9001}

read -p "${CYAN}Root User [default: minioadmin]: ${NC}" MINIO_ROOT_USER
MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}

read -p "${CYAN}Root Password [default: minioadmin]: ${NC}" MINIO_ROOT_PASS
MINIO_ROOT_PASS=${MINIO_ROOT_PASS:-minioadmin}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# MinIO Configuration
PROJECT_NAME=$PROJECT_NAME
MINIO_API_PORT=$MINIO_API_PORT
MINIO_CONSOLE_PORT=$MINIO_CONSOLE_PORT
MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASS=$MINIO_ROOT_PASS
MINIO_SERVER_URL=http://localhost:$MINIO_API_PORT

# Bucket Names
MINIO_BUCKET1=uploads
MINIO_BUCKET2=data
MINIO_BUCKET3=archives

# Region
MINIO_REGION=us-east-1

# Certificates (optional)
MINIO_CERTS_DIR=/path/to/certs
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  minio:
    container_name: \${PROJECT_NAME:-minio}-app
    image: \${MINIO_IMAGE:-minio/minio}:\${MINIO_VERSION:-latest}
    ports:
      - "\${MINIO_API_PORT:-9000}:\${MINIO_API_PORT:-9000}"
      - "\${MINIO_CONSOLE_PORT:-9001}:\${MINIO_CONSOLE_PORT:-9001}"
    volumes:
      - \${PROJECT_NAME:-minio}-data:/export
      - \${PROJECT_NAME:-minio}-config:/root/.minio
    environment:
      MINIO_ROOT_USER: \${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: \${MINIO_ROOT_PASS:-minioadmin}
      MINIO_SERVER_URL: \${MINIO_SERVER_URL:-http://localhost:$MINIO_API_PORT}
      MINIO_REGION: \${MINIO_REGION:-us-east-1}
    command: server /export --console-address :${MINIO_CONSOLE_PORT:-9001}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  minio-init:
    container_name: ${PROJECT_NAME:-minio}-init
    image: minio/mc:latest
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "
        sleep 5;
        mc alias set local http://minio:${MINIO_API_PORT:-9000} \${MINIO_ROOT_USER:-minioadmin} \${MINIO_ROOT_PASS:-minioadmin};
        mc mb --ignore-existing local/\${MINIO_BUCKET1:-uploads};
        mc mb --ignore-existing local/\${MINIO_BUCKET2:-data};
        mc mb --ignore-existing local/\${MINIO_BUCKET3:-archives};
        echo 'Buckets created';
      "

EOF

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-minio}-data:
  ${PROJECT_NAME:-minio}-config:
EOF

cat > "$PROJECT_DIR/init-buckets.sh" << 'SCRIPT'
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

echo "Creating default buckets..."

for bucket in ${MINIO_BUCKET1:-uploads} ${MINIO_BUCKET2:-data} ${MINIO_BUCKET3:-archives}; do
    echo "Creating bucket: $bucket"
    $COMPOSE_CMD run --rm minio-init mc mb --ignore-existing "local/$bucket" 2>/dev/null || true
done

echo "Buckets initialized!"
SCRIPT

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting MinIO services..."

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

echo -e "\033[0;32mMinIO started!\033[0m"
echo -e "S3 API: \033[1;33mhttp://localhost:$MINIO_API_PORT${MINIO_API_PORT:-9000}\033[0m"
echo -e "Console: \033[1;33mhttp://localhost:$MINIO_CONSOLE_PORT${MINIO_CONSOLE_PORT:-9001}\033[0m"
echo -e "Credentials: ${MINIO_ROOT_USER:-minioadmin} / ${MINIO_ROOT_PASS:-minioadmin}"
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

echo "Stopping MinIO services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
.vscode/
.idea/
certs/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
certs/
*.log
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

MinIO - S3-Compatible Object Storage

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh init-buckets.sh
./start-all.sh
\`\`\`

## Access

- S3 API: http://localhost:${MINIO_API_PORT:-9000}
- Console: http://localhost:${MINIO_CONSOLE_PORT:-9001}
- User: ${MINIO_ROOT_USER:-minioadmin}
- Password: ${MINIO_ROOT_PASS:-minioadmin}

## Usage

\`\`\`bash
# Configure AWS CLI
aws --endpoint-url http://localhost:${MINIO_API_PORT:-9000} s3 ls

# Create bucket
aws --endpoint-url http://localhost:${MINIO_API_PORT:-9000} s3 mb s3://uploads
\`\`\`

## Configuration

Edit \`.env\`:
- Ports for API and Console
- Root credentials
- Default buckets
- Region
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh" "$PROJECT_DIR/init-buckets.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MinIO project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "API: ${YELLOW}${MINIO_API_PORT:-9000}${NC}, Console: ${YELLOW}${MINIO_CONSOLE_PORT:-9001}${NC}"
echo ""
