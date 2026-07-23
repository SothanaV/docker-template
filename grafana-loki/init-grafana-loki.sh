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
    echo "Example: $0 my-loki"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Grafana Loki project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Grafana Loki Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Include Grafana dashboard:${NC}"
echo "  1) Yes with Grafana (default)"
echo "  2) Loki only"
read -p "  Enter choice [1]: " graf_choice
graf_choice="${graf_choice:-1}"

echo -e "\n${YELLOW}Select storage:${NC}"
echo "  1) Local (default)"
echo "  2) S3 (AWS)"
read -p "  Enter choice [1]: " store_choice
store_choice="${store_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
LOKI_PORT=3100
GRAFANA_PORT=3000
"

# Build docker-compose
if [ "$graf_choice" = "1" ]; then
    dockerfile_content="services:
    loki:
        container_name: \${PROJECT_NAME}-loki
        image: grafana/loki:latest
        volumes:
            - loki_data:/loki
            - ./config/loki-config.yml:/etc/loki/local-config.yaml
        ports:
            - \"\${LOKI_PORT}:3100\"
        healthcheck:
            test: [\"CMD\", \"wget\", \"--spider\", \"-q\", \"http://localhost:3100/ready\"]
            interval: 30s
            timeout: 10s
            retries: 5
            start_period: 30s
        restart: unless-stopped

    grafana:
        container_name: \${PROJECT_NAME}-grafana
        image: grafana/grafana:latest
        volumes:
            - grafana_data:/var/lib/grafana
            - ./config/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml
        environment:
            GF_SECURITY_ADMIN_USER: admin
            GF_SECURITY_ADMIN_PASSWORD: admin
            GF_INSTALL_PLUGINS: grafana-clock-panel
        ports:
            - \"\${GRAFANA_PORT}:3000\"
        depends_on:
            loki:
                condition: service_healthy
        restart: unless-stopped
volumes:
    loki_data:
    grafana_data:
"
else
    dockerfile_content="services:
    loki:
        container_name: \${PROJECT_NAME}-loki
        image: grafana/loki:latest
        volumes:
            - loki_data:/loki
            - ./config/loki-config.yml:/etc/loki/local-config.yaml
        ports:
            - \"\${LOKI_PORT}:3100\"
        healthcheck:
            test: [\"CMD\", \"wget\", \"--spider\", \"-q\", \"http://localhost:3100/ready\"]
            interval: 30s
            timeout: 10s
            retries: 5
            start_period: 30s
        restart: unless-stopped
volumes:
    loki_data:
"
fi

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Loki config
create_file "$PROJECT_DIR/config/loki-config.yml" "auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
"

# Datasource config for Grafana
mkdir -p "$PROJECT_DIR/config"
create_file "$PROJECT_DIR/config/datasource.yml" "apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
"

create_file "$PROJECT_DIR/.dockerignore" "loki_data/
grafana_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
*.db
.DS_Store
loki_data/
grafana_data/
"

create_file "$PROJECT_DIR/start-loki.sh" "#!/bin/bash
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

echo \"Starting Loki...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mLoki started!\"
echo -e \"Loki API:   \033[1;33mlocalhost:\${LOKI_PORT:-3100}\033[0m\"
echo -e \"Grafana:    \033[1;33mlocalhost:\${GRAFANA_PORT:-3000}\033[0m (if enabled)\"
echo -e \"Logs:       \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:       \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-loki.sh" "#!/bin/bash
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

echo \"Stopping Loki...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-loki.sh"
chmod +x "$PROJECT_DIR/stop-loki.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Grafana Loki Log Aggregation

## Quick Start

\`\`\`bash
chmod +x start-loki.sh stop-loki.sh
./start-loki.sh
\`\`\`

## Access

- Loki API: http://localhost:${LOKI_PORT:-3100}
- Grafana: http://localhost:${GRAFANA_PORT:-3000} (if enabled)
- Grafana creds: admin/admin

## Sample Query (Loki)

\`\`\`bash
curl -s 'http://localhost:3100/loki/api/v1/query?query={job=\"app\"}' | jq
\`\`\`

## Commands

- **Start:** \`./start-loki.sh\`
- **Stop:** \`./stop-loki.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Grafana Loki project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Grafana:    ${YELLOW}$( [ "$graf_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo -e "  Storage:    ${YELLOW}Local${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-loki.sh stop-loki.sh"
echo "3. ./start-loki.sh"
echo ""
