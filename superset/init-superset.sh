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

echo -e "${GREEN}Creating Superset project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 8088]: ${NC}" SUPERSET_PORT
SUPERSET_PORT=${SUPERSET_PORT:-8088}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: Y]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-Y}

read -p "${CYAN}Use Redis for caching? (y/N) [default: Y]: ${NC}" USE_RDIS
USE_RDIS=${USE_RDIS^^}
USE_RDIS=${USE_RDIS:-Y}

read -p "${CYAN}Admin password [default: admin]: ${NC}" SUPERSET_ADMIN_PASS
SUPERSET_ADMIN_PASS=${SUPERSET_ADMIN_PASS:-admin}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Superset Configuration
PROJECT_NAME=$PROJECT_NAME
SUPERSET_PORT=$SUPERSET_PORT

# Superset secret key
SUPERSET_SECRET_KEY=changeme-change-this-to-something-random

# Flask settings
FLASK_APP=superset
FLASK_ENV=production
SUPERSET_ENV=production

# Postgres
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
SQLALCHEMY_DATABASE_URI=postgresql+psycopg2://postgres:postgres@localhost:5432/superset
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=superset
EOF
fi
cat <<EOF

# Redis (caching, async queries, FAB)
EOF
if [ "$USE_RDIS" = "Y" ]; then
    cat <<EOF
RESULT_BACKEND=redis://localhost:6379/0
CACHE_CONFIG={"CACHE_TYPE": "RedisCache", "CACHE_REDIS_URL": "redis://localhost:6379/0"}
DATA_CACHE_CONFIG={"CACHE_TYPE": "RedisCache", "CACHE_REDIS_URL": "redis://localhost:6379/0"}
REDIS_HOST=localhost
REDIS_PORT=6379
EOF
fi
cat <<EOF

# Celery Workers
SUPERSET_WORKERS=4
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  superset:
    container_name: \${PROJECT_NAME:-superset}-app
    image: \${SUPERSET_IMAGE:-apache/superset}:\${SUPERSET_VERSION:-latest}
    ports:
      - "\${SUPERSET_PORT:-8088}:8088"
    volumes:
      - \${PROJECT_NAME:-superset}-uploads:/app/pythonpath
      - \${PROJECT_NAME:-superset}-config:/app/config
    environment:
      - SUPERSET_SECRET_KEY=\${SUPERSET_SECRET_KEY:-changeme}
      - SQLALCHEMY_DB_URI=postgresql+psycopg2://postgres:postgres@postgres:5432/superset
      - REDIS_HOST=\${REDIS_HOST:-localhost}
      - REDIS_PORT=\${REDIS_PORT:-6379}
      - SUPERSET_LOAD_EXAMPLES=yes
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8088/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    depends_on:
      superset-init:
        condition: service_completed_successfully

  superset-init:
    container_name: ${PROJECT_NAME:-superset}-init
    image: ${SUPERSET_IMAGE:-apache/superset}:${SUPERSET_VERSION:-latest}
    environment:
      - SUPERSET_SECRET_KEY=${SUPERSET_SECRET_KEY:-changeme}
      - SQLALCHEMY_DB_URI=postgresql+psycopg2://postgres:postgres@postgres:5432/superset
    volumes:
      - ${PROJECT_NAME:-superset}-uploads:/app/pythonpath
      - ${PROJECT_NAME:-superset}-config:/app/config
    command: >
      bash -c "
        superset db upgrade &&
        superset fab create-admin --username admin --firstname Admin --lastname Admin --email admin@example.com --password ${SUPERSET_ADMIN_PASS:-admin} &&
        superset init
      "

  superset-worker:
    container_name: ${PROJECT_NAME:-superset}-worker
    image: ${SUPERSET_IMAGE:-apache/superset}:${SUPERSET_VERSION:-latest}
    volumes:
      - ${PROJECT_NAME:-superset}-uploads:/app/pythonpath
      - ${PROJECT_NAME:-superset}-config:/app/config
    environment:
      - SUPERSET_SECRET_KEY=${SUPERSET_SECRET_KEY:-changeme}
      - SQLALCHEMY_DB_URI=postgresql+psycopg2://postgres:postgres@postgres:5432/superset
      - REDIS_HOST=${REDIS_HOST:-localhost}
      - REDIS_PORT=${REDIS_PORT:-6379}
    command: superset worker
    restart: unless-stopped
    depends_on:
      superset-init:
        condition: service_completed_successfully

EOF

if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-superset}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: superset
    volumes:
      - superset-pgdata:/var/lib/postgresql/data
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

if [ "$USE_RDIS" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  redis:
    container_name: ${PROJECT_NAME:-superset}-redis
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - superset-redisdata:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-superset}-uploads:
  ${PROJECT_NAME:-superset}-config:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  superset-pgdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi
if [ "$USE_RDIS" = "Y" ]; then
    echo "  superset-redisdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Superset services..."
echo "First run may take 2-3 minutes for initialization..."

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

echo -e "\033[0;32mSuperset started!\033[0m"
echo -e "Superset UI: \033[1;33mhttp://localhost:$SUPERSET_PORT${SUPERSET_PORT:-8088}\033[0m"
echo -e "Login: admin / admin"
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

echo "Stopping Superset services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
.vscode/
.idea/
*.csv
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
__pycache__/
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Apache Superset - Data Visualization & BI Platform

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

First initialization may take 2-3 minutes.

## Access

- UI: http://localhost:${SUPERSET_PORT:-8088}
- Login: admin / admin

## Configuration

Edit \`.env\`:
- \`SUPERSET_PORT\`: Web UI port
- \`SUPERSET_SECRET_KEY\`: Encryption key
- Database connection strings
- Redis settings

## Connect Databases

After first login, connect data sources:
- PostgreSQL, MySQL, BigQuery, Snowflake, etc.

## Volumes

- \${PROJECT_NAME}-uploads: Uploads storage
- \${PROJECT_NAME}-config: Config storage
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Superset project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${SUPERSET_PORT:-8088}${NC}"
echo ""
