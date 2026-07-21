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

echo -e "${GREEN}Creating Jupyter project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 8888]: ${NC}" JUPYTER_PORT
JUPYTER_PORT=${JUPYTER_PORT:-8888}

read -p "${CYAN}Password [default: changeme]: ${NC}" JUPYTER_PASSWORD
JUPYTER_PASSWORD=${JUPYTER_PASSWORD:-changeme}

read -p "${CYAN}Working directory [default: /workspace]: ${NC}" JUPYTER_WORKDIR
JUPYTER_WORKDIR=${JUPYTER_WORKDIR:-/workspace}

read -p "${CYAN}Python version [default: 3.12]: ${NC}" JUPYTER_PYTHON
JUPYTER_PYTHON=${JUPYTER_PYTHON:-3.12}

read -p "${CYAN}Install JupyterLab? (y/N) [default: Y]: ${NC}" USE_JLAB
USE_JLAB=${USE_JLAB^^}
USE_JLAB=${USE_JLAB:-Y}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Jupyter Configuration
PROJECT_NAME=$PROJECT_NAME
JUPYTER_PORT=$JUPYTER_PORT
JUPYTER_PASSWORD=$JUPYTER_PASSWORD
JUPYTER_WORKDIR=$JUPYTER_WORKDIR
JUPYTER_PYTHON_VERSION=$JUPYTER_PYTHON
USE_JUPYTERLAB=$USE_JLAB

# Jupyter settings
JUPYTER_ALLOW_ROOT=true
JUPYTER_IP=0.0.0.0
JUPYTER_TOKEN=
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  jupyter:
    container_name: \${PROJECT_NAME:-jupyter}-app
    image: \${JUPYTER_IMAGE:-jupyter/scipy-notebook}:\${JUPYTER_PYTHON_VERSION:-3.12}-latest
    ports:
      - "\${JUPYTER_PORT:-8888}:8888"
    volumes:
      - \${PROJECT_NAME:-jupyter}-data:\${JUPYTER_WORKDIR:-/workspace}
    environment:
      - JUPYTER_ENABLE_LAB=\${USE_JUPYTERLAB:-yes}
      - JUPYTER_PASSWORD=\${JUPYTER_PASSWORD:-changeme}
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8888/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
      # Note: Notebooks don't support /health, use API check

volumes:
  ${PROJECT_NAME:-jupyter}-data:
EOF

# Create start script that handles both ported and raw URLs
cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Jupyter services..."

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

echo -e "\033[0;32mJupyter started!\033[0m"
echo -e "Jupyter: \033[1;33mhttp://localhost:$JUPYTER_PORT${JUPYTER_PORT:-8888}\033[0m"
echo -e "Password: \033[1;33m${JUPYTER_PASSWORD:-changeme}\033[0m"
echo -e "Logs: \033[1;33m$COMPOSE_CMD logs -f\033[0m"
echo -e "Stop: \033[1;33m$COMPOSE_CMD down\033[0m"
echo ""
echo -e "Note: Check container logs for the exact URL with token"
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

echo "Stopping Jupyter services..."
$COMPOSE_CMD down
echo "Services stopped!"
SCRIPT

cat > "$PROJECT_DIR/.dockerignore" << 'EOF'
.git/
*.ipynb
.ipynb_checkpoints/
__pycache__/
*.pyc
.env
.vscode/
.idea/
*.md
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
__pycache__/
*.pyc
.ipynb_checkpoints/
data/
output/
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Jupyter Notebook / JupyterLab

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

\`\`\`bash
./stop-all.sh
\`\`\`

## Access

- Jupyter: http://localhost:${JUPYTER_PORT:-8888}
- Password: ${JUPYTER_PASSWORD:-changeme}

## Configuration

Edit \`.env\`:
- \`JUPYTER_PORT\`: Web UI port
- \`JUPYTER_PASSWORD\`: Login password
- \`JUPYTER_WORKDIR\`: Persistent workspace directory
- \`USE_JUPYTERLAB\`: Enable JupyterLab (yes/no)

## Included Tools

- Scientific Python stack (numpy, pandas, scipy, matplotlib)
- JupyterLab (if enabled)
- Data science libraries
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jupyter project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${JUPYTER_PORT:-8888}${NC}"
echo ""
