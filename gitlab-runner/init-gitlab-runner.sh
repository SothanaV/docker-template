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

echo -e "${GREEN}Creating GitLab Runner project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}GitLab URL [default: http://localhost]: ${NC}" GITLAB_URL
GITLAB_URL=${GITLAB_URL:-http://localhost}

read -p "${CYAN}GitLab token [required]: ${NC}" GITLAB_TOKEN
GITLAB_TOKEN=${GITLAB_TOKEN:-}

read -p "${CYAN}Runner tag(s) [default: docker]: ${NC}" RUNNER_TAGS
RUNNER_TAGS=${RUNNER_TAGS:-docker}

read -p "${CYAN}Concurrency [default: 10]: ${NC}" RUNNER_CONCURRENCY
RUNNER_CONCURRENCY=${RUNNER_CONCURRENCY:-10}

read -p "${CYAN}Runner exec method [docker, kubernetes] [default: docker]: ${NC}" RUNNER_EXEC
RUNNER_EXEC=${RUNNER_EXEC:-docker}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# GitLab Runner Configuration
PROJECT_NAME=$PROJECT_NAME
GITLAB_URL=$GITLAB_URL
GITLAB_TOKEN=${GITLAB_TOKEN:-}
RUNNER_TAGS=$RUNNER_TAGS
RUNNER_CONCURRENCY=$RUNNER_CONCURRENCY
RUNNER_EXEC=$RUNNER_EXEC

# Docker-in-Docker settings
DOCKER_IN_DOCKER=true
DOCKER_HOST=tcp://docker:2375
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  gitlab-runner:
    container_name: \${PROJECT_NAME:-gitlab-runner}-runner
    image: gitlab/gitlab-runner:\${GITLAB_RUNNER_VERSION:-latest}
    ports:
      - "2376:2376"
    volumes:
      - \${PROJECT_NAME:-gitlab-runner}-config:/etc/gitlab-runner
      - \${PROJECT_NAME:-gitlab-runner}-sock:/var/run
    environment:
      - CI_SERVER_URL=\${GITLAB_URL:-http://gitlab:80}/
      - REGISTRATION_TOKEN=\${GITLAB_TOKEN:-}
      - RUNNER_TAGS=\${RUNNER_TAGS:-docker}
      - RUNNER_EXEC=\${RUNNER_EXEC:-docker}
      - DOCKER_IN_DOCKER=\${DOCKER_IN_DOCKER:-true}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "gitlab-runner", "verify"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    depends_on:
      - docker
    privileged: true

  docker:
    container_name: \${PROJECT_NAME:-gitlab-runner}-docker
    image: docker:dind
    ports:
      - "2376:2376"
    environment:
      - DOCKER_TLS_CERTDIR=/certs
    volumes:
      - \${PROJECT_NAME:-gitlab-runner}-docker-certs:/certs
      - \${PROJECT_NAME:-gitlab-runner}-docker-data:/var/lib/docker
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "docker", "info"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
EOF

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  ${PROJECT_NAME:-gitlab-runner}-config:
  ${PROJECT_NAME:-gitlab-runner}-sock:
  ${PROJECT_NAME:-gitlab-runner}-docker-certs:
  ${PROJECT_NAME:-gitlab-runner}-docker-data:
EOF

cat > "$PROJECT_DIR/register-runner.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -z "$GITLAB_URL" ] || [ -z "$GITLAB_TOKEN" ]; then
    echo "Error: GITLAB_URL and GITLAB_TOKEN must be set"
    echo "Usage: Source .env first: source .env && ./register-runner.sh"
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

echo "Registering GitLab Runner..."

TAGS="${RUNNER_TAGS:-docker}"

$COMPOSE_CMD run --rm gitlab-runner \
    gitlab-runner register \
    --non-interactive \
    --executor "$RUNNER_EXEC" \
    --docker-image alpine:latest \
    --url "$GITLAB_URL" \
    --registration-token "$GITLAB_TOKEN" \
    --description "$PROJECT_NAME-runner" \
    --tag-list "$TAGS" \
    --run-untagged=true \
    --locked=false \
    --access-level=not_protected

echo "Runner registered successfully!"
SCRIPT

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting GitLab Runner services..."

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

echo -e "\033[0;32mGitLab Runner started!\033[0m"
echo -e "Docker-in-Docker: \033[1;33mtcp://localhost:2376\033[0m"
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

echo "Stopping GitLab Runner services..."
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
.gitlab/
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

GitLab Runner

CI/CD runner for GitLab CI/CD pipelines.

## Prerequisites

- GitLab instance URL
- GitLab registration token

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh register-runner.sh
./start-all.sh
./register-runner.sh
\`\`\`

## Configuration

Edit \`.env\`:
- \`GITLAB_URL\`: Your GitLab instance URL
- \`GITLAB_TOKEN\`: GitLab registration token
- \`RUNNER_TAGS\`: Comma-separated tags
- \`RUNNER_EXEC\`: Execution method (docker, kubernetes)

## Volumes

- \${PROJECT_NAME}-config: Runner configuration
- \${PROJECT_NAME}-docker-data: Docker-in-Docker data
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh" "$PROJECT_DIR/register-runner.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GitLab Runner project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Docker-in-Docker: ${YELLOW}tcp://localhost:2376${NC}"
echo ""
