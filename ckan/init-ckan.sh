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

echo -e "${GREEN}Creating CKAN project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Frontend Port [default: 5000]: ${NC}" CKAN_FRONT_PORT
CKAN_FRONT_PORT=${CKAN_FRONT_PORT:-5000}

read -p "${CYAN}Search Backend [elasticsearch, whoosh] [default: elasticsearch]: ${NC}" CKAN_SEARCH
CKAN_SEARCH=${CKAN_SEARCH:-elasticsearch}

read -p "${CYAN}Enable Elasticsearch? (y/N) [default: Y]: ${NC}" USE_ES
USE_ES=${USE_ES^^}
USE_ES=${USE_ES:-Y}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# CKAN Configuration
PROJECT_NAME=$PROJECT_NAME
CKAN_FRONT_PORT=$CKAN_FRONT_PORT
CKAN_SEARCH_BACKEND=$CKAN_SEARCH

# Database
PSQL_HOST=localhost
PSQL_PORT=5432
PSQL_USER=ckanuser
PSQL_PASSWORD=ckanpassword
PSQL_DB=ckan_main
PSQL_TEST_DB=ckan_test

# Elasticsearch
EOF
if [ "$USE_ES" = "Y" ]; then
    cat <<EOF
ES_HOST=localhost
ES_PORT=9200
EOF
fi
cat <<EOF

# CKAN server
SITE_URL=http://localhost:$CKAN_FRONT_PORT
SECRET_KEY=changeme-to-secure-random-string

# SMTP (optional)
MAIL_SERVER=localhost
MAIL_PORT=25
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  ckan:
    container_name: \${PROJECT_NAME:-ckan}-app
    image: \${CKAN_IMAGE:-quay.io/ckan/ckan}:\${CKAN_VERSION:-latest}
    ports:
      - "\${CKAN_FRONT_PORT:-5000}:5000"
    volumes:
      - \${PROJECT_NAME:-ckan}-data:/var/lib/ckan
    environment:
      - CKAN_SITE_URL=\${SITE_URL:-http://localhost:$CKAN_FRONT_PORT}
      - CKAN_DATASOURCES_URL=http://localhost:$CKAN_FRONT_PORT/datasources
      - CKAN_SENTRY_DSN=
      - CKAN_SMTP_MAIL_FROM=
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/3/action/status_show"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  postgres:
    container_name: ${PROJECT_NAME:-ckan}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${PSQL_USER:-ckanuser}
      POSTGRES_PASSWORD: ${PSQL_PASSWORD:-ckanpassword}
      POSTGRES_DB: ${PSQL_DB:-ckan_main}
    volumes:
      - ckan-pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ckanuser"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF

if [ "$USE_ES" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  elasticsearch:
    container_name: ${PROJECT_NAME:-ckan}-elasticsearch
    image: elasticsearch:8.13.0
    ports:
      - "9200:9200"
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    volumes:
      - ckan-esdata:/usr/share/elasticsearch/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "elasticsearch-keystore", "list"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-ckan}-data:
  ckan-pgdata:
EOF
if [ "$USE_ES" = "Y" ]; then
    echo "  ckan-esdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting CKAN services..."

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

echo -e "\033[0;32mCKAN started!\033[0m"
echo -e "CKAN: \033[1;33mhttp://localhost:$CKAN_FRONT_PORT${CKAN_FRONT_PORT:-5000}\033[0m"
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

echo "Stopping CKAN services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
vscode/
.idea/
*.pyc
__pycache__/
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
.env.*
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

CKAN - Data Portal & Collaboration Platform

Open-source data portal platform for managing and publishing datasets.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

## Access

- CKAN: http://localhost:${CKAN_FRONT_PORT:-5000}

## Configuration

Edit \`.env\`:
- \`CKAN_FRONT_PORT\`: Frontend port
- Database credentials
- Elasticsearch settings
- Site URL
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CKAN project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${CKAN_FRONT_PORT:-5000}${NC}"
echo ""
