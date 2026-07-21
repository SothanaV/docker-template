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

echo -e "${GREEN}Creating SonarQube project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 9000]: ${NC}" SONAR_PORT
SONAR_PORT=${SONAR_PORT:-9000}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: Y]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-Y}

read -p "${CYAN}Admin password [default: admin]: ${NC}" SONAR_ADMIN_PASS
SONAR_ADMIN_PASS=${SONAR_ADMIN_PASS:-admin}

read -p "${CYAN}SonarQube edition [community,developer,enterprise] [default: community]: ${NC}" SONAR_EDITION
SONAR_EDITION=${SONAR_EDITION:-community}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# SonarQube Configuration
PROJECT_NAME=$PROJECT_NAME
SONAR_PORT=$SONAR_PORT
SONAR_ADMIN_PASS=$SONAR_ADMIN_PASS
SONAR_EDITION=$SONAR_EDITION

# PostgreSQL
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
SONAR_JDBC_USERNAME=postgres
SONAR_JDBC_PASSWORD=postgres
SONAR_JDBC_URL=jdbc:postgresql://localhost:5432/sonarqube
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=sonarqube
EOF
fi
cat <<EOF

# Java VM Options
SONAR_JAVA_MAX_MEM=2g
SONAR_JAVA_MAX_NEW_MEM=512m
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  sonarqube:
    container_name: \${PROJECT_NAME:-sonarqube}-app
    image: \${SONAR_IMAGE:-sonarqube}:\${SONAR_EDITION:-community}-community
    ports:
      - "\${SONAR_PORT:-9000}:9000"
    volumes:
      - \${PROJECT_NAME:-sonarqube}-data:/opt/sonarqube/data
      - \${PROJECT_NAME:-sonarqube}-extensions:/opt/sonarqube/extensions
      - \${PROJECT_NAME:-sonarqube}-logs:/opt/sonarqube/logs
      - \${PROJECT_NAME:-sonarqube}-temp:/opt/sonarqube/temp
    environment:
      SONAR_JDBC_USERNAME: \${SONAR_JDBC_USERNAME:-postgres}
      SONAR_JDBC_PASSWORD: \${SONAR_JDBC_PASSWORD:-postgres}
      SONAR_JDBC_URL: \${SONAR_JDBC_URL:-jdbc:postgresql://postgres:5432/sonarqube}
      SONAR_WEB_PORT: 9000
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/api/system/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5m
    deploy:
      resources:
        limits:
          memory: 4g
    mem_limit: 4g
EOF

if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-sonarqube}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: sonarqube
      # SonarQube requires specific PostgreSQL settings
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
    volumes:
      - sonarqube-pgdata:/var/lib/postgresql/data
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

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-sonarqube}-data:
  ${PROJECT_NAME:-sonarqube}-extensions:
  ${PROJECT_NAME:-sonarqube}-logs:
  ${PROJECT_NAME:-sonarqube}-temp:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  sonarqube-pgdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting SonarQube services..."
echo "WARNING: SonarQube is resource-intensive. Ensure at least 4GB RAM."

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

echo -e "\033[0;32mSonarQube started!\033[0m"
echo -e "SonarQube UI: \033[1;33mhttp://localhost:$SONAR_PORT${SONAR_PORT:-9000}\033[0m"
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

echo "Stopping SonarQube services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
.vscode/
.idea/
*.log
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
*.sqlite
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

SonarQube - Code Quality & Analysis Platform

## Prerequisites

- 4GB+ RAM recommended
- Disk space for analysis data

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

SonarQube takes ~5 minutes to fully start on first run.

## Access

- UI: http://localhost:${SONAR_PORT:-9000}
- Default login: admin / admin

## Configuration

Edit \`.env\`:
- \`SONAR_PORT\`: Web interface port
- \`SONAR_ADMIN_PASS\`: Admin password
- \`SONAR_JDBC_URL\`: Database connection URL

## Analyzing Code

\`\`\`bash
# Using sonar-scanner
docker run --rm \
  -e SONAR_HOST_URL="http://localhost:$SONAR_PORT" \
  -e SONAR_LOGIN="admin:${SONAR_ADMIN_PASS:-admin}" \
  sonarsource/sonar-scanner-cli
\`\`\`

## Volumes

- \${PROJECT_NAME}-data: SonarQube data
- \${PROJECT_NAME}-extensions: Plugins
- \${PROJECT_NAME}-logs: Logs
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SonarQube project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${SONAR_PORT:-9000}${NC}"
echo ""
