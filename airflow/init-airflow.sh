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

echo -e "${GREEN}Creating Airflow project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Webserver Port [default: 8080]: ${NC}" AIRFLOW_PORT
AIRFLOW_PORT=${AIRFLOW_PORT:-8080}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: Y]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-Y}

read -p "${CYAN}Use Redis for triggers? (y/N) [default: N]: ${NC}" USE_RDIS
USE_RDIS=${USE_RDIS^^}
USE_RDIS=${USE_RDIS:-N}

read -p "${CYAN}Enable Celery executor? (y/N) [default: N]: ${NC}" USE_CELERY
USE_CELERY=${USE_CELERY^^}
USE_CELERY=${USE_CELERY:-N}

read -p "${CYAN}Airflow version [default: 2.10]: ${NC}" AIRFLOW_VERSION
AIRFLOW_VERSION=${AIRFLOW_VERSION:-2.10}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Airflow Configuration
PROJECT_NAME=$PROJECT_NAME
AIRFLOW_PORT=$AIRFLOW_PORT
AIRFLOW_VERSION=$AIRFLOW_VERSION

# Airflow settings
AIRFLOW_USER=admin
AIRFLOW_PASSWORD=admin
AIRFLOW_EMAIL=admin@example.com
AIRFLOW_URL=http://localhost:$AIRFLOW_PORT

# PostgreSQL (default backend)
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://postgres:postgres@localhost:5432/airflow
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=airflow
EOF
fi
cat <<EOF

# Redis (optional, for triggers)
EOF
if [ "$USE_RDIS" = "Y" ]; then
    cat <<EOF
AIRFLOW__CORE__RESULT_BACKEND=redis://localhost:6379/0
AIRFLOW__TRIGGERS__DEV_MODE=TRUE
REDIS_HOST=localhost
REDIS_PORT=6379
EOF
fi
cat <<EOF

# Celery (optional)
EOF
if [ "$USE_CELERY" = "Y" ]; then
    cat <<EOF
AIRFLOW__CORE__EXECUTOR=CeleryExecutor
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://postgres:postgres@postgres:5432/airflow
EOF
fi
cat <<EOF

# Timezone
AIRFLOW__CORE__TIMEZONE=UTC
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  airflow-webserver:
    container_name: \${PROJECT_NAME:-airflow}-webserver
    image: \${AIRFLOW_IMAGE:-apache/airflow}:\${AIRFLOW_VERSION:-2.10}-python3.11
    ports:
      - "\${AIRFLOW_PORT:-8080}:8080"
    volumes:
      - \${PROJECT_NAME:-airflow}-dags:/opt/airflow/dags
      - \${PROJECT_NAME:-airflow}-logs:/opt/airflow/logs
      - \${PROJECT_NAME:-airflow}-plugins:/opt/airflow/plugins
    environment:
      - AIRFLOW__CORE__EXECUTOR=SequentialExecutor
      - AIRFLOW__CORE__AUTHENTICATOR=airflow.providers.fab.authenticator.fab.FabAuthenticator
EOF
if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << EOF
      - AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://postgres:postgres@postgres:5432/airflow
EOF
fi
cat >> "$PROJECT_DIR/docker-compose.yml" << EOF
      - AIRFLOW__WEBSERVER__EXPOSE_CONFIG=true
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "airflow db check"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    depends_on:
      - airflow-init
    command: airflow webserver

  airflow-scheduler:
    container_name: \${PROJECT_NAME:-airflow}-scheduler
    image: \${AIRFLOW_IMAGE:-apache/airflow}:\${AIRFLOW_VERSION:-2.10}-python3.11
    volumes:
      - \${PROJECT_NAME:-airflow}-dags:/opt/airflow/dags
      - \${PROJECT_NAME:-airflow}-logs:/opt/airflow/logs
      - \${PROJECT_NAME:-airflow}-plugins:/opt/airflow/plugins
    environment:
      - AIRFLOW__CORE__EXECUTOR=SequentialExecutor
      - AIRFLOW__CORE__AUTHENTICATOR=airflow.providers.fab.authenticator.fab.FabAuthenticator
EOF
if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << EOF
      - AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://postgres:postgres@postgres:5432/airflow
EOF
fi
cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
    restart: unless-stopped
    depends_on:
      - airflow-init
    command: airflow scheduler

  airflow-init:
    container_name: ${PROJECT_NAME:-airflow}-init
    image: ${AIRFLOW_IMAGE:-apache/airflow}:${AIRFLOW_VERSION:-2.10}-python3.11
    environment:
      - AIRFLOW__CORE__EXECUTOR=SequentialExecutor
      - AIRFLOW__CORE__AUTHENTICATOR=airflow.providers.fab.authenticator.fab.FabAuthenticator
EOF
if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
      - AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://postgres:postgres@postgres:5432/airflow
EOF
fi
cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
    command: >
      bash -c "
        airflow users create --username ${AIRFLOW_USER:-admin} --password ${AIRFLOW_PASSWORD:-admin} --firstname Admin --lastname Admin --role Admin --email ${AIRFLOW_EMAIL:-admin@example.com} || true &&
        airflow db upgrade
      "
    volumes:
      - ${PROJECT_NAME:-airflow}-dags:/opt/airflow/dags
      - ${PROJECT_NAME:-airflow}-logs:/opt/airflow/logs
      - ${PROJECT_NAME:-airflow}-plugins:/opt/airflow/plugins

EOF

if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-airflow}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: airflow
    volumes:
      - airflow-pgdata:/var/lib/postgresql/data
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
    container_name: ${PROJECT_NAME:-airflow}-redis
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - airflow-redisdata:/data
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
  ${PROJECT_NAME:-airflow}-dags:
  ${PROJECT_NAME:-airflow}-logs:
  ${PROJECT_NAME:-airflow}-plugins:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  airflow-pgdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi
if [ "$USE_RDIS" = "Y" ]; then
    echo "  airflow-redisdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi

cat > "$PROJECT_DIR/create-dags-dir.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/dags"
mkdir -p "$SCRIPT_DIR/plugins"
echo "Created dags/ and plugins/ directories"
SCRIPT

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Airflow services..."
echo "This may take a few minutes on first run..."

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

echo -e "\033[0;32mAirflow started!\033[0m"
echo -e "Airflow UI: \033[1;33mhttp://localhost:$AIRFLOW_PORT${AIRFLOW_PORT:-8080}\033[0m"
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

echo "Stopping Airflow services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
dags/
*.md
.env
.vscode/
.idea/
__pycache__/
*.py
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
__pycache__/
dags/__pycache__/
dags/*.py
*.log
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Apache Airflow - Workflow Orchestration Platform

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh create-dags-dir.sh
./create-dags-dir.sh
./start-all.sh
\`\`\`

## Access

- Airflow UI: http://localhost:${AIRFLOW_PORT:-8080}
- Login: admin / admin

## Configuration

Edit \`.env\`:
- \`AIRFLOW_PORT\`: Web UI port
- \`AIRFLOW_USER\`: Admin username
- \`AIRFLOW_PASSWORD\`: Admin password
- Database credentials

## DAGs

Place DAG files in the \`dags/\` directory.
Custom operators/hooks go in \`plugins/\`.

## Executor Options

- SequentialExecutor (default, single machine)
- CeleryExecutor (requires Redis + Flower)
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh" "$PROJECT_DIR/create-dags-dir.sh"
mkdir -p "$PROJECT_DIR/../$PROJECT_NAME/dags" "$PROJECT_DIR/../$PROJECT_NAME/plugins" 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Airflow project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${AIRFLOW_PORT:-8080}${NC}"
echo ""
