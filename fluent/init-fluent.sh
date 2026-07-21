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

echo -e "${GREEN}Creating Fluent Bit project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}HTTP server port [default: 2020]: ${NC}" FLUENT_HTTP_PORT
FLUENT_HTTP_PORT=${FLUENT_HTTP_PORT:-2020}

read -p "${CYAN}Backend type [elasticsearch, loki, splunk, awscloudwatch, null] [default: loki]: ${NC}" FLUENT_BACKEND
FLUENT_BACKEND=${FLUENT_BACKEND:-loki}

read -p "${CYAN}Input type [tail, forward, http] [default: tail]: ${NC}" FLUENT_INPUT
FLUENT_INPUT=${FLUENT_INPUT:-tail}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Fluent Bit Configuration
PROJECT_NAME=$PROJECT_NAME
FLUENT_HTTP_PORT=$FLUENT_HTTP_PORT
FLUENT_BACKEND=$FLUENT_BACKEND
FLUENT_INPUT=$FLUENT_INPUT

# Backend URL
LOKI_URL=http://localhost:3100/loki/api/v1/push
ELASTIC_URL=http://localhost:9200
AWS_REGION=us-east-1

# Fluent Settings
FLUENT_LOG_LEVEL=info
FLUENT_WORKER=2
EOF

cat > "$PROJECT_DIR/fluent-bit.conf" <<'EOF'
[SERVICE]
    Flush        1
    Daemon       Off
    Log_Level    ${FLUENT_LOG_LEVEL:-info}
    Parsers_File parsers.conf
    HTTP_Server  On
    HTTP_Listen  0.0.0.0
    HTTP_PORT    ${FLUENT_HTTP_PORT:-2020}

[INPUT]
    Name   ${FLUENT_INPUT:-tail}
    Path   /var/log/*.log
    Parser docker
    Tag    logs.*
    Refresh_Interval 10

[FILTER]
    Name   modify
    Match  logs.*
    Add    kubernetes.namespace_name unknown

[OUTPUT]
    Name   ${FLUENT_BACKEND:-loki}
    Match  *
    Host   ${LOKI_URL:-localhost}
    URI    /loki/api/v1/push
    Label  keys=true
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  fluent-bit:
    container_name: \${PROJECT_NAME:-fluent-bit}-app
    image: \${FLUENT_IMAGE:-cr.fluent.io/fluent/fluent-bit}:\${FLUENT_VERSION:-latest}
    ports:
      - "\${FLUENT_HTTP_PORT:-2020}:2020"
    volumes:
      - ./fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro
      - ./parsers.conf:/fluent-bit/etc/parsers.conf:ro
      - /var/log:/var/log:ro
    environment:
      - FLUENT_LOG_LEVEL=\${FLUENT_LOG_LEVEL:-info}
      - FLUENT_BACKEND=\${FLUENT_BACKEND:-loki}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:2020/api/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s

EOF

case "$FLUENT_BACKEND" in
    loki)
        cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  loki:
    container_name: ${PROJECT_NAME:-fluent-bit}-loki
    image: grafana/loki:3.0.0
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/loki-config.yml:ro
    command: -config.file=/loki-config.yml
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3100/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
        ;;
    elasticsearch)
        cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  elasticsearch:
    container_name: ${PROJECT_NAME:-fluent-bit}-elasticsearch
    image: elasticsearch:8.13.0
    ports:
      - "9200:9200"
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    volumes:
      - fluent-esdata:/usr/share/elasticsearch/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9200/_cluster/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
        ;;
esac

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF

volumes:
  fluent-esdata:
EOF

cat > "$PROJECT_DIR/parsers.conf" << 'EOF'
[PARSER]
    Name   apache
    Format regex
    Regex  ^(?<remote>[^ ]*) (?<host>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?)(?: +\S*)?)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?$
    Time_Key time
    Time_Format %d/%b/%Y:%H.%M.%S %z

[PARSER]
    Name   docker
    Format json
    Time_Key time
    Time_Format %Y-%m-%dT%H:%M:%S.%LZ
EOF

cat > "$PROJECT_DIR/loki-config.yml" << 'EOF'
auth_enabled: false

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

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
EOF

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Fluent Bit services..."

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

echo -e "\033[0;32mFluent Bit started!\033[0m"
echo -e "HTTP API: \033[1;33mhttp://localhost:$FLUENT_HTTP_PORT${FLUENT_HTTP_PORT:-2020}\033[0m"
echo -e "Health: \033[1;33mhttp://localhost:$FLUENT_HTTP_PORT${FLUENT_HTTP_PORT:-2020}/api/v1/health\033[0m"
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

echo "Stopping Fluent Bit services..."
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
fluent-bit.conf
parsers.conf
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
.env
*.log
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Fluent Bit - Log Shipper

Lightweight log shipper and processor for logs, metrics, and events.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh
./start-all.sh
\`\`\`

## Access

- HTTP API: http://localhost:${FLUENT_HTTP_PORT:-2020}
- Health: http://localhost:${FLUENT_HTTP_PORT:-2020}/api/v1/health

## Configuration

Edit \`.env\`:
- \`FLUENT_HTTP_PORT\`: HTTP API port
- \`FLUENT_BACKEND\`: Output backend (loki, elasticsearch, etc.)
- \`FLUENT_INPUT\`: Input source (tail, forward, http)

Edit \`fluent-bit.conf\` and \`parsers.conf\` for advanced configuration.
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Fluent Bit project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${FLUENT_HTTP_PORT:-2020}${NC}"
echo ""
