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
    echo "Example: $0 my-elasticsearch"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Elasticsearch project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Elasticsearch Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select version:${NC}"
echo "  1) Elasticsearch 8.14 (default)"
echo "  2) Elasticsearch 7.17 LTS"
echo "  3) OpenSearch 2.14"
read -p "  Enter choice [1]: " ver_choice
ver_choice="${ver_choice:-1}"
case $ver_choice in
    1) SELECT_VER="8.14.0" ; IMAGE="elasticsearch" ;;
    2) SELECT_VER="7.17.25" ; IMAGE="elasticsearch" ;;
    3) SELECT_VER="2.14.0"  ; IMAGE="opensearchproject/opensearch" ;;
esac

echo -e "\n${YELLOW}Select Kibana/OpenSearch Dashboards:${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -p "  Enter choice [1]: " dash_choice
dash_choice="${dash_choice:-1}"

echo -e "\n${YELLOW}Memory limit (GB):${NC}"
echo "  1) 1GB (dev, default)"
echo "  2) 2GB"
echo "  3) 4GB"
read -p "  Enter choice [1]: " mem_choice
mem_choice="${mem_choice:-1}"
case $mem_choice in
    1) SELECT_MEM="1g" ;;
    2) SELECT_MEM="2g" ;;
    3) SELECT_MEM="4g" ;;
esac

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
ELASTIC_PASSWORD='${PROJECT_NAME}_elastic_pass'
ES_PORT=9200
"

# Build docker-compose
dockerfile_content="services:
    elasticsearch:
        container_name: \${PROJECT_NAME}-es
        image: ${IMAGE}:${SELECT_VER}
        volumes:
            - es_data:/usr/share/elasticsearch/data
        environment:
            node.name: es1
            cluster.name: ${PROJECT_NAME}
            discovery.type: single-node
            bootstrap.memory_lock: \"true\"
            ES_JAVA_OPTS: \"-Xms${SELECT_MEM} -Xmx${SELECT_MEM}\"
            ELASTIC_PASSWORD: \${ELASTIC_PASSWORD}
            xpack.security.enabled: \"true\"
            xpack.security.http.ssl.enabled: \"false\"
        ports:
            - \"\${ES_PORT}:9200\"
        healthcheck:
            test: [\"CMD\", \"curl\", \"-f\", \"-u\", \"elastic:\${ELASTIC_PASSWORD}\", \"http://localhost:9200/_cluster/health\"]
            interval: 30s
            timeout: 10s
            retries: 5
            start_period: 120s
        restart: unless-stopped
"

if [ "$dash_choice" = "1" ]; then
    if [ "$IMAGE" = "opensearchproject/opensearch" ]; then
        dashboard_image="opensearchproject/opensearch-dashboards"
    else
        dashboard_image="kibana"
    fi
    dockerfile_content+=$'
    kibana:
        container_name: ${PROJECT_NAME}-kibana
        image: '"$dashboard_image:${SELECT_VER}"'\
        environment:
            ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
            ELASTICSEARCH_USERNAME: "elastic"
            ELASTICSEARCH_PASSWORD: "${ELASTIC_PASSWORD}"
        ports:
            - "5051:5601"
        depends_on:
            elasticsearch:
                condition: service_healthy
        restart: unless-stopped
'
fi

dockerfile_content+="
volumes:
    es_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Index templates
create_file "$PROJECT_DIR/init/index-template.json" "{
  \"index_patterns\": [\"logs-${PROJECT_NAME}-*\"],
  \"template\": {
    \"mappings\": {
      \"properties\": {
        \"@timestamp\": { \"type\": \"date\" },
        \"message\": { \"type\": \"text\" },
        \"level\": { \"type\": \"keyword\" },
        \"service\": { \"type\": \"keyword\" },
        \"host\": { \"type\": \"keyword\" }
      }
    }
  }
}
"

create_file "$PROJECT_DIR/.dockerignore" "es_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
es_data/
"

create_file "$PROJECT_DIR/start-elasticsearch.sh" "#!/bin/bash
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

echo \"Starting Elasticsearch...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mElasticsearch started!\"
echo -e \"API:     \033[1;33mhttp://localhost:\${ES_PORT:-9200}\033[0m\"
echo -e \"Dashboards:\033[1;33m localhost:5051\033[0m (if enabled)\"
echo -e \"Password: \033[1;33m${ELASTIC_PASSWORD:-${PROJECT_NAME}_elastic_pass}\033[0m\"
echo -e \"Logs:     \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:     \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-elasticsearch.sh" "#!/bin/bash
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

echo \"Stopping Elasticsearch...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-elasticsearch.sh"
chmod +x "$PROJECT_DIR/stop-elasticsearch.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Elasticsearch ${SELECT_VER}

## Quick Start

\`\`\`bash
chmod +x start-elasticsearch.sh stop-elasticsearch.sh
./start-elasticsearch.sh
\`\`\`

## Access

- API: http://localhost:${ES_PORT:-9200}
- User: elastic
- Password: ${ELASTIC_PASSWORD:-${PROJECT_NAME}_elastic_pass}

## Commands

- **Start:** \`./start-elasticsearch.sh\`
- **Stop:** \`./stop-elasticsearch.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`

## Sample Query

\`\`\`bash
curl -s -u elastic:${ELASTIC_PASSWORD:-pass} http://localhost:9200/_cluster/health | jq
\`\`\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Elasticsearch project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Version:          ${YELLOW}$SELECT_VER ($IMAGE)${NC}"
echo -e "  Dashboards:       ${YELLOW}$( [ "$dash_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo -e "  Memory Limit:     ${YELLOW}$SELECT_MEM${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-elasticsearch.sh stop-elasticsearch.sh"
echo "3. ./start-elasticsearch.sh"
echo ""
