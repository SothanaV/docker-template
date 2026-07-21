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

echo -e "${GREEN}Creating OpenProject template: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Web Port [default: 8080]: ${NC}" OP_WEB_PORT
OP_WEB_PORT=${OP_WEB_PORT:-8080}

read -p "${CYAN}Webserver Port [default: 9292]: ${NC}" OP_SERVER_PORT
OP_SERVER_PORT=${OP_SERVER_PORT:-9292}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: Y]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-Y}

read -p "${CYAN}Use Nginx reverse proxy? (y/N) [default: N]: ${NC}" USE_NGINX
USE_NGINX=${USE_NGINX^^}
USE_NGINX=${USE_NGINX:-N}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Open Project Template Configuration
PROJECT_NAME=$PROJECT_NAME
OP_WEB_PORT=$OP_WEB_PORT
OP_SERVER_PORT=$OP_SERVER_PORT

# Admin credentials
OP_ADMIN_USER=admin
OP_ADMIN_EMAIL=admin@example.com
OP_ADMIN_PASSWORD=changeme

# Database
EOF
if [ "$USE_PG" = "Y" ]; then
    cat <<EOF
DB_NAME=projectapp
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
EOF
fi
cat <<EOF

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Session
SECRET_KEY=changeme-rotate-in-production
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  webapp:
    container_name: \${PROJECT_NAME:-openproject}-app
    image: \${OPENPROJECT_IMAGE:-openproject/core}:\${OPENPROJECT_VERSION:-latest}
    ports:
      - "\${OP_WEB_PORT:-8080}:\${OP_WEB_PORT:-8080}"
    volumes:
      - \${PROJECT_NAME:-openproject}-data:/var/openproject/assets
    environment:
      SECRET_KEY_BASE: \${SECRET_KEY:-changeme}
      OP_ADMIN_USER: \${OP_ADMIN_USER:-admin}
      OP_ADMIN_EMAIL: \${OP_ADMIN_EMAIL:-admin@example.com}
      OP_ADMIN_PASSWORD: \${OP_ADMIN_PASSWORD:-changeme}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/v3/status.json"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    depends_on:
      init:
        condition: service_completed_successfully

  webserver:
    container_name: ${PROJECT_NAME:-openproject}-server
    image: ${OPENPROJECT_IMAGE:-openproject/core}:${OPENPROJECT_VERSION:-latest}
    volumes:
      - ${PROJECT_NAME:-openproject}-data:/var/openproject/assets
    environment:
      SECRET_KEY_BASE: ${SECRET_KEY:-changeme}
      RAILS_ENV: production
      DB_USERNAME: postgres
      DB_PASSWORD: postgres
      DB_DATABASE: projectapp
      RAILS_SERVE_STATIC_FILES: "true"
    restart: unless-stopped
    command: ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "9292"]
    depends_on:
      - webapp
      - init

  init:
    container_name: ${PROJECT_NAME:-openproject}-init
    image: ${OPENPROJECT_IMAGE:-openproject/core}:${OPENPROJECT_VERSION:-latest}
    environment:
      SECRET_KEY_BASE: ${SECRET_KEY:-changeme}
    command: >
      bash -c "
        bundle exec rake db:create || true &&
        bundle exec rake db:migrate || true &&
        echo 'Database initialized';
      "
    volumes:
      - ${PROJECT_NAME:-openproject}-data:/var/openproject/assets
    restart: "no"

EOF

if [ "$USE_PG" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  postgres:
    container_name: ${PROJECT_NAME:-openproject}-postgres
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: projectapp
    volumes:
      - openproject-pgdata:/var/lib/postgresql/data
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

if [ "$USE_NGINX" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  nginx:
    container_name: ${PROJECT_NAME:-openproject}-nginx
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - webapp
      - webserver
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3

EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-openproject}-data:
EOF
if [ "$USE_PG" = "Y" ]; then
    echo "  openproject-pgdata:" >> "$PROJECT_DIR/docker-compose.yml"
fi

# Create nginx.conf if needed
if [ "$USE_NGINX" = "Y" ]; then
    cat > "$PROJECT_DIR/nginx.conf" << 'EOF'
upstream webapp {
    server webapp:8080;
}

upstream webserver {
    server webserver:9292;
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://webapp;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api {
        proxy_pass http://webapp;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
fi

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting OpenProject services..."
echo "First run will initialize the database..."

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

echo -e "\033[0;32mOpenProject template started!\033[0m"
echo -e "Web App: \033[1;33mhttp://localhost:$OP_WEB_PORT${OP_WEB_PORT:-8080}\033[0m"
echo -e "API: \033[1;33mhttp://localhost:$OP_WEB_PORT${OP_WEB_PORT:-8080}/api/v3/\033[0m"
echo -e "Admin: ${OP_ADMIN_USER:-admin} / ${OP_ADMIN_PASSWORD:-changeme}"
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

echo "Stopping OpenProject services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.md
.env
.vscode/
.idea/
node_modules/
dist/
__pycache__/
*.pyc
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
.env.*
node_modules/
dist/
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

OpenProject - Fullstack Project Template

A flexible fullstack project template with web app, API, and optional database.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

## Access

- Web App: http://localhost:${OP_WEB_PORT:-8080}
- API: http://localhost:${OP_WEB_PORT:-8080}/api/v3/
- Admin: ${OP_ADMIN_USER:-admin} / ${OP_ADMIN_PASSWORD:-changeme}

## Services

- **Web App**: Frontend interface
- **Webserver**: API/Rails backend
- **PostgreSQL**: [Optional] Database
- **Nginx**: [Optional] Reverse proxy

## Configuration

Edit \`.env\`:
- Database credentials
- Admin user settings
- Secret key
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OpenProject template created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${OP_WEB_PORT:-8080}${NC}"
echo ""
