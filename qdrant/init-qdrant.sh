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
    echo "Example: $0 my-qdrant"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Qdrant project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Qdrant Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select API:${NC}"
echo "  1) REST only (default)"
echo "  2) REST + gRPC"
read -p "  Enter choice [1]: " api_choice
api_choice="${api_choice:-1}"
case $api_choice in
    1) SELECT_API="rest" ;;
    2) SELECT_API="rest-grpc" ;;
esac

echo -e "\n${YELLOW}Select Dashboard:${NC}"
echo "  1) Qdrant Dashboard (default)"
echo "  2) None"
read -p "  Enter choice [1]: " dash_choice
dash_choice="${dash_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
QDRANT_PORT=6333
QDRANT_GRPC_PORT=6334
QDRANT_API_KEY='${PROJECT_NAME}_api_key'
"

# Build docker-compose
if [ "$SELECT_API" = "rest-grpc" ]; then
    dockerfile_content="services:
    qdrant:
        container_name: \${PROJECT_NAME}-qdrant
        image: qdrant/qdrant:latest
        volumes:
            - qdrant_data:/qdrant/storage
        ports:
            - \"\${QDRANT_PORT}:6333\"
            - \"\${QDRANT_GRPC_PORT}:6334\"
        environment:
            QDRANT__SERVICE__API_KEY: \${QDRANT_API_KEY}
        healthcheck:
            test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:6333/health\"]
            interval: 30s
            timeout: 10s
            retries: 5
            start_period: 30s
        restart: unless-stopped
"
    if [ "$dash_choice" = "1" ]; then
        dockerfile_content+=$'
    qdrant-ui:
        container_name: ${PROJECT_NAME}-qdrant-ui
        image: ghcr.io/qdrant/qdrant-web-ui:latest
        ports:
            - "5051:3000"
        environment:
            QDRANT_URL: http://qdrant:6333
        depends_on:
            qdrant:
                condition: service_healthy
        restart: unless-stopped
'
    fi
    dockerfile_content+=$'
volumes:
    qdrant_data:
'
else
    dockerfile_content="services:
    qdrant:
        container_name: \${PROJECT_NAME}-qdrant
        image: qdrant/qdrant:latest
        volumes:
            - qdrant_data:/qdrant/storage
        ports:
            - \"\${QDRANT_PORT}:6333\"
        environment:
            QDRANT__SERVICE__API_KEY: \${QDRANT_API_KEY}
        healthcheck:
            test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:6333/health\"]
            interval: 30s
            timeout: 10s
            retries: 5
            start_period: 30s
        restart: unless-stopped
"
    dockerfile_content+=$'
volumes:
    qdrant_data:
'
fi

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Example collection
create_file "$PROJECT_DIR/init/collection.json" "{
  \"vector\": {
    \"size\": 768,
    \"distance\": \"Cosine\"
  },
  \"hnsw_config\": {
    \"m\": 16,
    \"ef_construct\": 100
  },
  \"optimizers_config\": {
    \"max_segment_number\": 8
  }
}
"

create_file "$PROJECT_DIR/.dockerignore" "qdrant_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
qdrant_data/
"

create_file "$PROJECT_DIR/start-qdrant.sh" "#!/bin/bash
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

echo \"Starting Qdrant...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mQdrant started!\"
echo -e \"REST:    \033[1;33mlocalhost:\${QDRANT_PORT:-6333}\033[0m\"
echo -e \"UI:      \033[1;33mlocalhost:5051\033[0m (if enabled)\"
echo -e \"Docs:    \033[1;33mlocalhost:\${QDRANT_PORT:-6333}/docs\033[0m\"
echo -e \"Logs:    \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:    \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-qdrant.sh" "#!/bin/bash
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

echo \"Stopping Qdrant...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-qdrant.sh"
chmod +x "$PROJECT_DIR/stop-qdrant.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Qdrant Vector Database

## Quick Start

\`\`\`bash
chmod +x start-qdrant.sh stop-qdrant.sh
./start-qdrant.sh
\`\`\`

## Access

- REST API: http://localhost:${QDRANT_PORT:-6333}
- API Docs: http://localhost:${QDRANT_PORT:-6333}/docs
- API Key: Qdrant::${QDRANT_API_KEY:-${PROJECT_NAME}_api_key}

## Python Client

\`\`\`python
from qdrant_client import QdrantClient

client = QdrantClient(
    url=\"http://localhost:${QDRANT_PORT:-6333}\",
    api_key=\"${QDRANT_API_KEY:-${PROJECT_NAME}_api_key}\"
)
\`\`\`

## Commands

- **Start:** \`./start-qdrant.sh\`
- **Stop:** \`./stop-qdrant.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Qdrant project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  API Mode:   ${YELLOW}$SELECT_API${NC}"
echo -e "  Dashboard:  ${YELLOW}$( [ "$dash_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-qdrant.sh stop-qdrant.sh"
echo "3. ./start-qdrant.sh"
echo ""
