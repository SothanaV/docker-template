#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-ollama"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Ollama project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Ollama Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select model to pull:${NC}"
echo "  1) llama3 (default)"
echo "  2) mistral"
echo "  3) codellama"
echo "  4) phi3"
echo "  5) none"
read -p "  Enter choice [1]: " model_choice
model_choice="${model_choice:-1}"
case $model_choice in
    1) SELECT_MODEL="llama3" ;;
    2) SELECT_MODEL="mistral" ;;
    3) SELECT_MODEL="codellama" ;;
    4) SELECT_MODEL="phi3" ;;
    5) SELECT_MODEL="" ;;
esac

echo -e "\n${YELLOW}Select Web UI:${NC}"
echo "  1) Ollama Web UI (default)"
echo "  2) None"
read -p "  Enter choice [1]: " ui_choice
ui_choice="${ui_choice:-1}"

echo -e "\n${YELLOW}GPU Support:${NC}"
echo "  1) CPU only (default)"
echo "  2) NVIDIA GPU"
read -p "  Enter choice [1]: " gpu_choice
gpu_choice="${gpu_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
OLLAMA_PORT=11434
OLLAMA_HOST=0.0.0.0
"

# Build docker-compose
dockerfile_content="services:
    ollama:
        container_name: \${PROJECT_NAME}-ollama
        image: ollama/ollama:latest
        volumes:
            - ollama_data:/root/.ollama
"

if [ "$gpu_choice" = "2" ]; then
    dockerfile_content+=$'
        deploy:
            resources:
                reservations:
                    devices:
                        - driver: nvidia
                          capabilities: [gpu]
'
fi

dockerfile_content+=$'
        ports:
            - "${OLLAMA_PORT}:11434"
        healthcheck:
            test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 60s
        restart: unless-stopped
'

if [ "$ui_choice" = "1" ]; then
    dockerfile_content+=$'
    webui:
        container_name: ${PROJECT_NAME}-webui
        image: ghcr.io/open-webui/open-webui:main
        volumes:
            - webui_data:/app/backend/data
        ports:
            - "5000:8080"
        environment:
            OLLAMA_BASE_URL: "http://ollama:11434"
            WEBUI_SECRET_KEY: ""
        depends_on:
            ollama:
                condition: service_healthy
        restart: unless-stopped
'
fi

dockerfile_content+="
volumes:
    ollama_data:
    webui_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

create_file "$PROJECT_DIR/.dockerignore" "ollama_data/
webui_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
ollama_data/
webui_data/
"

create_file "$PROJECT_DIR/start-ollama.sh" "#!/bin/bash
set -e

SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"
cd \"\$SCRIPT_DIR\"

if ! command -v docker &> /dev/null; then
    echo \"Error: docker not installed\"
    exit 1
fi

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker compose\"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker-compose\"
else
    echo \"Error: docker-compose not installed\"
    exit 1
fi

echo \"Starting Ollama...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mOllama started!\"
echo -e \"API:      \033[1;33mlocalhost:\${OLLAMA_PORT:-11434}\033[0m\"
echo -e \"Web UI:   \033[1;33mlocalhost:5000\033[0m (if enabled)\"
echo -e \"Docs:     \033[1;33mlocalhost:\${OLLAMA_PORT:-11434}/docs\033[0m\"

if [ -n \"\$SELECT_MODEL\" ]; then
    echo -e \"\033[1;33mPulling model: \$SELECT_MODEL...\033[0m\"
    docker compose exec ollama ollama pull \$SELECT_MODEL
fi

echo -e \"Logs:     \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:     \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-ollama.sh" "#!/bin/bash
SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"
cd \"\$SCRIPT_DIR\"

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker compose\"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker-compose\"
else
    echo \"Error: docker-compose not installed\"
    exit 1
fi

echo \"Stopping Ollama...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-ollama.sh"
chmod +x "$PROJECT_DIR/stop-ollama.sh"

# README
create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Ollama LLM Server

## Quick Start

\`\`\`bash
chmod +x start-ollama.sh stop-ollama.sh
./start-ollama.sh
\`\`\`

## Access

- API: http://localhost:${OLLAMA_PORT:-11434}
- Web UI: http://localhost:5000 (if enabled)

## CLI

\`\`\`bash
# List models
curl http://localhost:${OLLAMA_PORT:-11434}/api/tags

# Chat
curl http://localhost:${OLLAMA_PORT:-11434}/api/chat -d '{
  \"model\": \"llama3\",
  \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]
}'
\`\`\`

## Commands

- **Start:** \`./start-ollama.sh\`
- **Stop:** \`./stop-ollama.sh\`
- **Pull model:** \`docker compose exec ollama ollama pull llama3\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Ollama project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Model:      ${YELLOW}${SELECT_MODEL:-none}${NC}"
echo -e "  Web UI:     ${YELLOW}$( [ "$ui_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo -e "  GPU:        ${YELLOW}$( [ "$gpu_choice" = "2" ] && echo 'NVIDIA' || echo 'CPU' )${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-ollama.sh stop-ollama.sh"
echo "3. ./start-ollama.sh"
echo ""
