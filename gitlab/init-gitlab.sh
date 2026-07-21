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

echo -e "${GREEN}Creating GitLab project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}HTTP Port [default: 80]: ${NC}" GITLAB_HTTP_PORT
GITLAB_HTTP_PORT=${GITLAB_HTTP_PORT:-80}

read -p "${CYAN}HTTPS Port [default: 443]: ${NC}" GITLAB_HTTPS_PORT
GITLAB_HTTPS_PORT=${GITLAB_HTTPS_PORT:-443}

read -p "${CYAN}SSH Port [default: 22]: ${NC}" GITLAB_SSH_PORT
GITLAB_SSH_PORT=${GITLAB_SSH_PORT:-22}

read -p "${CYAN}GitLab edition [CE/EE] [default: CE]: ${NC}" GITLAB_EDITION
GITLAB_EDITION=${GITLAB_EDITION:-CE}

read -p "${CYAN}GitLab version [default: latest]: ${NC}" GITLAB_VERSION
GITLAB_VERSION=${GITLAB_VERSION:-latest}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# GitLab Self-Hosted Configuration
PROJECT_NAME=$PROJECT_NAME
GITLAB_HTTP_PORT=$GITLAB_HTTP_PORT
GITLAB_HTTPS_PORT=$GITLAB_HTTPS_PORT
GITLAB_SSH_PORT=$GITLAB_SSH_PORT
GITLAB_EDITION=$GITLAB_EDITION
GITLAB_VERSION=$GITLAB_VERSION

# GitLab Settings
GITLAB_ROOT_PASSWORD=changeme
GITLAB_HOSTNAME=localhost
GITLAB_PORT_HTTP=$GITLAB_HTTP_PORT
GITLAB_PORT_HTTPS=$GITLAB_HTTPS_PORT
GITLAB_PORT_SSH=$GITLAB_SSH_PORT

# Backup settings
GITLAB_BACKUP_TIME=00:00
GITLAB_BACKUP_KEEP_DAYS=7

# Monitoring
PROMETHEUS_ENABLED=false
GRAFANA_ENABLED=false
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  gitlab:
    container_name: \${PROJECT_NAME:-gitlab}-gitlab
    image: \${GITLAB_IMAGE:-gitlab/gitlab-ce}:\${GITLAB_VERSION:-latest}
    ports:
      - "\${GITLAB_HTTP_PORT:-80}:80"
      - "\${GITLAB_HTTPS_PORT:-443}:443"
      - "\${GITLAB_SSH_PORT:-22}:22"
    volumes:
      - \${PROJECT_NAME:-gitlab}-config:/etc/gitlab
      - \${PROJECT_NAME:-gitlab}-logs:/var/log/gitlab
      - \${PROJECT_NAME:-gitlab}-data:/var/opt/gitlab
    shm_size: '256m'
    environment:
      GITLAB_ROOT_PASSWORD: \${GITLAB_ROOT_PASSWORD:-changeme}
      GITLAB_HOSTNAME: \${GITLAB_HOSTNAME:-localhost}
      GITLAB_PORT_HTTP: \${GITLAB_PORT_HTTP:-80}
      GITLAB_PORT_HTTPS: \${GITLAB_PORT_HTTPS:-443}
      GITLAB_PORT_SSH: \${GITLAB_PORT_SSH:-22}
      GITLAB_backups: \${GITLAB_BACKUP_TIME:-00:00}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5m
    mem_limit: 4g
    mem_reservation: 2g
EOF

cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'

volumes:
  ${PROJECT_NAME:-gitlab}-config:
  ${PROJECT_NAME:-gitlab}-logs:
  ${PROJECT_NAME:-gitlab}-data:
EOF

cat > "$PROJECT_DIR/gitlab.rb" << 'EOF'
# GitLab Configuration
external_url 'http://localhost'
gitlab_rails['time_zone'] = 'UTC'
gitlab_rails['backup_keep_time'] = 604800
EOF

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting GitLab services..."
echo "WARNING: GitLab is resource-intensive. Ensure at least 4GB RAM available."

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

echo "Using: $COMPOSE_CMD"
echo "Starting GitLab (may take 2-5 minutes to initialize)..."
$COMPOSE_CMD up -d

echo -e "\033[0;32mGitLab starting...\033[0m"
echo -e "GitLab UI: \033[1;33mhttp://localhost:$GITLAB_HTTP_PORT${GITLAB_HTTP_PORT:-80}\033[0m"
echo -e "HTTPS: \033[1;33mhttps://localhost:$GITLAB_HTTPS_PORT${GITLAB_HTTPS_PORT:-443}\033[0m"
echo -e "SSH: \033[1;33mgit@localhost:$GITLAB_SSH_PORT${GITLAB_SSH_PORT:-22}\033[0m"
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

echo "Stopping GitLab services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/start-backup.sh" << 'SCRIPT'
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

echo "Running GitLab backup..."
$COMPOSE_CMD exec gitlab gitlab-rake gitlab:backup:create

echo "Backup created in /var/opt/gitlab/backups"
SCRIPT

cat > "$PROJECT_DIR/restore-backup.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_FILE="${1:-}"
if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file-name>"
    echo "List backups: docker compose exec gitlab ls /var/opt/gitlab/backups"
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

echo "Restoring GitLab backup: $BACKUP_FILE"
$COMPOSE_CMD exec gitlab gitlab-rake gitlab:backup:restore BACKUP="$BACKUP_FILE"
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
*.sqlite
.gitlab/
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

GitLab Self-Hosted

## Prerequisites

- 4GB+ RAM recommended
- 40GB+ disk space for volumes

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh start-backup.sh restore-backup.sh
./start-all.sh
\`\`\`

GitLab takes 2-5 minutes to fully start on first run.

## Access

- UI: http://localhost:${GITLAB_HTTP_PORT:-80}
- HTTPS: https://localhost:${GITLAB_HTTPS_PORT:-443}
- SSH: git@localhost:${GITLAB_SSH_PORT:-22}
- Default root password: changeme

## Configuration

Edit \`.env\`:
- \`GITLAB_HTTP_PORT\`: HTTP port
- \`GITLAB_HTTPS_PORT\`: HTTPS port
- \`GITLAB_SSH_PORT\`: SSH port
- \`GITLAB_ROOT_PASSWORD\`: Admin password

Edit \`gitlab.rb\` for advanced gitlab-rails settings.

## Backups

\`\`\`bash
# Create backup
./start-backup.sh

# Restore backup
./restore-backup.sh <backup-filename>

# List backups
docker compose exec gitlab ls /var/opt/gitlab/backups
\`\`\`

## Volumes

- \${PROJECT_NAME}-config: GitLab configuration
- \${PROJECT_NAME}-logs: GitLab logs
- \${PROJECT_NAME}-data: GitLab data (projects, databases, repositories)
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh" "$PROJECT_DIR/start-backup.sh" "$PROJECT_DIR/restore-backup.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GitLab project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Ports: HTTP=${YELLOW}${GITLAB_HTTP_PORT:-80}${NC}, HTTPS=${YELLOW}${GITLAB_HTTPS_PORT:-443}${NC}, SSH=${YELLOW}${GITLAB_SSH_PORT:-22}${NC}"
echo ""
