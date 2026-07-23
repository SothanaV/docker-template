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
    echo "Example: $0 my-meilisearch"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Meilisearch project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Meilisearch Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

read -p "  Select port [7700]: " port_choice
port_choice="${port_choice:-7700}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
MEILI_PORT=$port_choice
MEILI_HTTP_ADDR=0.0.0.0
"

dockerfile_content="services:
    meilisearch:
        container_name: \${PROJECT_NAME}-meilisearch
        image: getmeili/meilisearch:latest
        volumes:
            - meili_data:/meili_data
        environment:
            MEILI_NO_ANALYTICS: \"true\"
            MEILI_ENV: development
        ports:
            - \"\$MEILI_PORT:7700\"
        healthcheck:
            test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:7700/health\"]
            interval: 30s
            timeout: 10s
            retries: 5
            start_period: 30s
        restart: unless-stopped
volumes:
    meili_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Sample init script
create_file "$PROJECT_DIR/init/init.json" "{
  \"samples\": {
    \"movies\": {
      \"description\": \"Sample movie dataset for testing\"
    }
  }
}
"

create_file "$PROJECT_DIR/.dockerignore" "meili_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
meili_data/
"

create_file "$PROJECT_DIR/start-meilisearch.sh" "#!/bin/bash
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

echo \"Starting Meilisearch...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mMeilisearch started!\"
echo -e \"API:      \033[1;33mlocalhost:\${MEILI_PORT:-7700}\033[0m\"
echo -e \"Health:   \033[1;33mlocalhost:\${MEILI_PORT:-7700}/health\033[0m\"
echo -e \"Logs:     \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:     \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-meilisearch.sh" "#!/bin/bash
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

echo \"Stopping Meilisearch...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-meilisearch.sh"
chmod +x "$PROJECT_DIR/stop-meilisearch.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Meilisearch Search Engine

## Quick Start

\`\`\`bash
chmod +x start-meilisearch.sh stop-meilisearch.sh
./start-meilisearch.sh
\`\`\`

## Access

- API: http://localhost:${MEILI_PORT:-7700}
- Docs: http://localhost:${MEILI_PORT:-7700}/docs

## CLI

\`\`\`bash
curl http://localhost:${MEILI_PORT:-7700}/health
\`\`\`

## Default Admin Key

\`\`\`bash
MEILI_MASTER_KEY=change-me-in-production
\`\`\`

## Commands

- **Start:** \`./start-meilisearch.sh\`
- **Stop:** \`./stop-meilisearch.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Meilisearch project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Port:        ${YELLOW}${MEILI_PORT:-7700}${NC}"
echo ""
echo -e "Location:    ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-meilisearch.sh stop-meilisearch.sh"
echo "3. ./start-meilisearch.sh"
echo ""
