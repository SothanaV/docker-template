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

echo -e "${GREEN}Creating Debezium project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

read -p "${CYAN}Port [default: 8083]: ${NC}" DEBEZIUM_PORT
DEBEZIUM_PORT=${DEBEZIUM_PORT:-8083}

read -p "${CYAN}Use PostgreSQL? (y/N) [default: Y]: ${NC}" USE_PG
USE_PG=${USE_PG^^}
USE_PG=${USE_PG:-Y}

read -p "${CYAN}Use Kafka? (y/N) [default: Y]: ${NC}" USE_KAFKA
USE_KAFKA=${USE_KAFKA^^}
USE_KAFKA=${USE_KAFKA:-Y}

read -p "${CYAN}Use Schema Registry? (y/N) [default: Y]: ${NC}" USE_SCHEMA
USE_SCHEMA=${USE_SCHEMA^^}
USE_SCHEMA=${USE_SCHEMA:-Y}

create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

cat > "$PROJECT_DIR/.env" <<EOF
# Debezium Configuration
PROJECT_NAME=$PROJECT_NAME
DEBEZIUM_PORT=$DEBEZIUM_PORT
DEBEZIUM_VERSION=2.5

# Connector
DEBEZIUM_STORAGE_TYPE=internal
DEBEZIUM_CONFIG_STORAGE_TOPIC=${PROJECT_NAME:-debezium}-configs
DEBEZIUM_OFFSET_STORAGE_TOPIC=${PROJECT_NAME:-debezium}-offsets
DEBEZIUM_STATUS_STORAGE_TOPIC=${PROJECT_NAME:-debezium}-statuses

# Internal conversion
DEBEZIUM_KEY_CONVERTER=org.apache.kafka.connect.json.JsonConverter
DEBEZIUM_VALUE_CONVERTER=org.apache.kafka.connect.json.JsonConverter
EOF
if [ "$USE_KAFKA" = "Y" ]; then
    cat >> "$PROJECT_DIR/.env" << 'EOF'
DEBEZIUM_KEY_CONVERTER.SCHEMAS_ENABLE=false
DEBEZIUM_VALUE_CONVERTER.SCHEMAS_ENABLE=false
EOF
fi
cat >> "$PROJECT_DIR/.env" << EOF

# PostgreSQL monitoring (example)
MONITORED_PG_HOST=localhost
MONITORED_PG_PORT=5432
MONITORED_PG_USER=postgres
MONITORED_PG_PASSWORD=postgres
MONITORED_PG_DATABASE=postgres

# Kafka (optional)
EOF
if [ "$USE_KAFKA" = "Y" ]; then
    cat >> "$PROJECT_DIR/.env" << 'EOF'
KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092
KAFKA_BROKER_ID=1
KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1
KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1
KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1
EOF
fi
cat >> "$PROJECT_DIR/.env" << EOF

# Schema Registry (optional)
EOF
if [ "$USE_SCHEMA" = "Y" ]; then
    cat >> "$PROJECT_DIR/.env" << 'EOF'
SCHEMA_REGISTRY_HOST=localhost
SCHEMA_REGISTRY_PORT=8081
EOF
fi
cat >> "$PROJECT_DIR/.env" << 'EOF'

# Logging
LOG_LEVEL=INFO
EOF

cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
services:
  debezium:
    container_name: \${PROJECT_NAME:-debezium}-app
    image: \${DEBEZIUM_IMAGE:-debezium/connect}:\${DEBEZIUM_VERSION:-2.5}
    ports:
      - "\${DEBEZIUM_PORT:-8083}:8083"
    environment:
      BOOTSTRAP_SERVERS: \${KAFKA_BOOTSTRAP:-kafka:9092}
      GROUP_ID: 1
      CONFIG_STORAGE_TOPIC: \${DEBEZIUM_CONFIG_STORAGE_TOPIC:-debezium-configs}
      OFFSET_STORAGE_TOPIC: \${DEBEZIUM_OFFSET_STORAGE_TOPIC:-debezium-offsets}
      STATUS_STORAGE_TOPIC: \${DEBEZIUM_STATUS_STORAGE_TOPIC:-debezium-statuses}
      KEY_CONVERTER: \${DEBEZIUM_KEY_CONVERTER:-org.apache.kafka.connect.json.JsonConverter}
      VALUE_CONVERTER: \${DEBEZIUM_VALUE_CONVERTER:-org.apache.kafka.connect.json.JsonConverter}
EOF
if [ "$USE_KAFKA" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
      KEY_CONVERTER.SCHEMAS_ENABLE: "false"
      VALUE_CONVERTER.SCHEMAS_ENABLE: "false"
    depends_on:
      - kafka
EOF
fi
cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8083/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

EOF

if [ "$USE_KAFKA" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  zookeeper:
    container_name: ${PROJECT_NAME:-debezium}-zookeeper
    image: confluentinc/cp-zookeeper:7.6.0
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    volumes:
      - debezium-zkdata:/var/lib/zookeeper/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "echo", "ruok", "|", "nc", "localhost", "2181"]
      interval: 30s
      timeout: 10s
      retries: 3

  kafka:
    container_name: ${PROJECT_NAME:-debezium}-kafka
    image: confluentinc/cp-kafka:7.6.0
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_MIN_INSYNC_REPLICAS: 1
    depends_on:
      - zookeeper
    volumes:
      - debezium-kafkadata:/var/lib/kafka/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "kafka-broker-api-versions", "--bootstrap-server", "localhost:9092"]
      interval: 30s
      timeout: 10s
      retries: 3

EOF
fi

if [ "$USE_SCHEMA" = "Y" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
  schema-registry:
    container_name: ${PROJECT_NAME:-debezium}-schema-registry
    image: confluentinc/cp-schema-registry:7.6.0
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:9092
    depends_on:
      - kafka
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/"]
      interval: 30s
      timeout: 10s
      retries: 3

EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << EOF
volumes:
EOF
if [ "$USE_KAFKA" = "Y" ]; then
    echo "  debezium-zkdata:" >> "$PROJECT_DIR/docker-compose.yml"
    echo "  debezium-kafkadata:" >> "$PROJECT_DIR/docker-compose.yml"
fi

cat > "$PROJECT_DIR/register-connector.sh" <<'SCRIPT'
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

echo "Registering PostgreSQL connector..."

curl -X POST "http://localhost:8083/connectors" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "pg-connector",
    "config": {
      "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
      "database.hostname": "postgres",
      "database.port": "5432",
      "database.user": "postgres",
      "database.password": "postgres",
      "database.dbname": "postgres",
      "topic.prefix": "dbserver1",
      "schema.include.list": "public"
    }
  }'

echo -e "\033[0;32mPostgreSQL connector registered!\033[0m"
SCRIPT

cat > "$PROJECT_DIR/start-all.sh" << 'SCRIPT'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Debezium services..."

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

echo -e "\033[0;32mDebezium started!\033[0m"
echo -e "Debezium API: \033[1;33mhttp://localhost:$DEBEZIUM_PORT${DEBEZIUM_PORT:-8083}\033[0m"
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

echo "Stopping Debezium services..."
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
.vscode/
.idea/
.DS_Store
EOF

cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Debezium - Change Data Capture

Capture row-level changes in your databases in real-time.

## Quick Start

\`\`\`bash
chmod +x start-all.sh stop-all.sh register-connector.sh
./start-all.sh
./register-connector.sh
\`\`\`

## Access

- Debezium REST API: http://localhost:${DEBEZIUM_PORT:-8083}
- Kafka: localhost:9092 (if enabled)
- Schema Registry: localhost:8081 (if enabled)

## Configuration

Edit \`.env\`:
- \`DEBEZIUM_PORT\`: REST API port
- Database connection details
- Kafka bootstrap servers
- Connector topics
EOF

chmod +x "$PROJECT_DIR/start-all.sh" "$PROJECT_DIR/stop-all.sh" "$PROJECT_DIR/register-connector.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Debezium project created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Port: ${YELLOW}${DEBEZIUM_PORT:-8083}${NC}"
echo ""
