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

echo -e "${GREEN}Creating Label Studio project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 8080]: ${NC}" LABEL_STUDIO_PORT
LABEL_STUDIO_PORT=${LABEL_STUDIO_PORT:-8080}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: Y]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-Y}

read -p "${CYAN}Storage location [default: local]: ${NC}" STORAGE_TYPE
STORAGE_TYPE=${STORAGE_TYPE:-local}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

{
cat <<EOF
# Label Studio Environment Configuration
PROJECT_NAME=$PROJECT_NAME
LABEL_STUDIO_PORT=$LABEL_STUDIO_PORT

# Database
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/labelstudio
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=labelstudio
EOF
fi
cat <<EOF

# Storage
LABEL_STORAGE_TYPE=$STORAGE_TYPE

# Security
SECRET_KEY=changeme-to-secure-random-string

# Server
LABEL_STUDIO_THREADS=4
LOG_LEVEL=INFO
EOF
} > "$PROJECT_DIR/.env"

{
cat <<EOF
services:
  label-studio:
    container_name: \${PROJECT_NAME:-label-studio}-app
    image: \${LABEL_STUDIO_IMAGE:-heartexlabs/label-studio}:\${LABEL_STUDIO_VERSION:-latest}
    ports:
      - "\${LABEL_STUDIO_PORT:-8080}:8080"
    volumes:
      - \${PROJECT_NAME:-label-studio-data}:/label-studio/data
      - \${PROJECT_NAME:-label-studio-uploads}:/label-studio/uploads
    environment:
      - LABEL_STUDIO_PORT=\${LABEL_STUDIO_PORT:-8080}
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
      - LABEL_STUDIO_LOCAL_FILES_STORAGE_ENABLED=true
EOF
fi
cat <<EOF
      - LABEL_STUDIO_HOST=localhost
      - SECRET_KEY=\${SECRET_KEY:-changeme}
      - LOG_LEVEL=\${LOG_LEVEL:-INFO}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

if [ "$USE_PG" = "Y" ]; then
    cat <<'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-label-studio}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: labelstudio
    volumes:
      - labelstudio-pgdata:/var/lib/postgresql/data
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
  ${PROJECT_NAME:-label-studio}-data:
  ${PROJECT_NAME:-label-studio}-uploads:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  labelstudio-pgdata:"
fi

} > "$PROJECT_DIR/docker-compose.yml"

create_file "$PROJECT_DIR/start-all.sh" '#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Label Studio services..."

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

echo -e "\033[0;32mLabel Studio started!\033[0m"
echo -e "UI: \033[1;33mhttp://localhost:$LABEL_STUDIO_PORT${LABEL_STUDIO_PORT:-8080}\033[0m"
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

echo "Stopping Label Studio services..."
$COMPOSE_CMD down
echo "Services stopped!"
'

create_file "$PROJECT_DIR/.dockerignore" "# Data
data/
venv/
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
*.sqlite
data/
venv/
__pycache__/
.vscode/
.idea/
.DS_Store
*.log
"

create_file "$PROJECT_DIR/README.md" "# $PROJECT_NAME

Label Studio - Data Labeling Platform

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- UI: http://localhost:${LABEL_STUDIO_PORT:-8080}
- Default login: First user becomes admin

## Features

- Image, text, audio, video labeling
- Interactive ML-powered labeling (optional)
- Export to popular formats
- Team collaboration
- Versioned projects

## Configuration

Edit \`.env\`:
- \`LABEL_STUDIO_PORT\`: Server port
- \`SECRET_KEY\`: Encryption key
- \`DATABASE_URL\`: Database connection
"

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Label Studio project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${LABEL_STUDIO_PORT:-8080}${NC}"
echo ""
