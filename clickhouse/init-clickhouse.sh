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
    echo "Example: $0 my-clickhouse"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating ClickHouse project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   ClickHouse Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select version:${NC}"
echo "  1) ClickHouse 24.8 (default)"
echo "  2) ClickHouse latest"
read -p "  Enter choice [1]: " ver_choice
ver_choice="${ver_choice:-1}"
case $ver_choice in
    1) SELECT_VER="24.8" ; IMAGE_VER="24.8.7" ;;
    2) SELECT_VER="latest" ; IMAGE_VER="latest" ;;
esac

echo -e "\n${YELLOW}Select DBeaver Web UI:${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -p "  Enter choice [1]: " dbeaver_choice
dbeaver_choice="${dbeaver_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
CLICKHOUSE_USER=clickhouse
CLICKHOUSE_PASSWORD='${PROJECT_NAME}_password'
CLICKHOUSE_DB=${PROJECT_NAME}_db
CLICKHOUSE_HTTP_PORT=8123
CLICKHOUSE_NATIVE_PORT=9000
"

dockerfile_content="services:
    clickhouse:
        container_name: \${PROJECT_NAME}-db
        image: clickhouse/clickhouse-server:${IMAGE_VER}
        volumes:
            - clickhouse_data:/var/lib/clickhouse
            - ./config:/etc/clickhouse-server/config.d:ro
        environment:
            CLICKHOUSE_USER: \${CLICKHOUSE_USER}
            CLICKHOUSE_PASSWORD: \${CLICKHOUSE_PASSWORD}
            CLICKHOUSE_DB: \${CLICKHOUSE_DB}
        ports:
            - \"\${CLICKHOUSE_HTTP_PORT}:8123\"
            - \"\${CLICKHOUSE_NATIVE_PORT}:9000\"
        healthcheck:
            test: [\"CMD\", \"wget\", \"--spider\", \"-q\", \"http://localhost:8123/ping\"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 30s
        restart: unless-stopped
"

if [ "$dbeaver_choice" = "1" ]; then
    dockerfile_content+=$'
    dbeaver:
        container_name: ${PROJECT_NAME}-dbeaver
        image: dpage/pgadmin4:latest
        ports:
            - "5051:80"
        environment:
            PGADMIN_DEFAULT_EMAIL: admin@clickhouse.local
            PGADMIN_DEFAULT_PASSWORD: admin
        command: [\"/bin/bash\", \"-c\", \"echo Dashboard\\\"]
        restart: unless-stopped
'
fi

dockerfile_content+="
volumes:
    clickhouse_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Config for ClickHouse
create_file "$PROJECT_DIR/config/settings.xml" "<?xml version=\"1.0\"?>
<clickhouse>
    <logger>
        <level>warning</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
    </logger>

    <query_log>
        <database>_system</database>
        <table>query_log</table>
        <partition_by>toYYYYMM(event_date)</partition_by>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_log>
</clickhouse>
"

create_file "$PROJECT_DIR/config/users.xml" "<?xml version=\"1.0\"?>
<clickhouse>
    <profiles>
        <default>
            <max_memory_usage>10000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>in_order</load_balancing>
        </default>
    </profiles>
</clickhouse>
"

# Init SQL
create_file "$PROJECT_DIR/init/01-init.sql" "-- Create initial tables
CREATE TABLE IF NOT EXISTS measurements (
    id UInt64,
    timestamp DateTime,
    sensor_id String,
    value Float64,
    created_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (sensor_id, timestamp);

-- Sample data
INSERT INTO measurements (id, timestamp, sensor_id, value) VALUES
    (1, now(), 'sensor-1', 23.5),
    (2, now(), 'sensor-1', 24.1),
    (3, now(), 'sensor-2', 19.8);
"

create_file "$PROJECT_DIR/.dockerignore" "clickhouse_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
clickhouse_data/
"

create_file "$PROJECT_DIR/start-clickhouse.sh" "#!/bin/bash
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

echo \"Starting ClickHouse...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mClickHouse started!\"
echo -e \"HTTP:     \033[1;33mlocalhost:\${CLICKHOUSE_HTTP_PORT:-8123}\033[0m\"
echo -e \"Native:   \033[1;33mlocalhost:\${CLICKHOUSE_NATIVE_PORT:-9000}\033[0m\"
echo -e \"Ping:     \033[1;33mcurl http://localhost:8123/\033[0m\"
echo -e \"Logs:     \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:     \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-clickhouse.sh" "#!/bin/bash
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

echo \"Stopping ClickHouse...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-clickhouse.sh"
chmod +x "$PROJECT_DIR/stop-clickhouse.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

ClickHouse ${SELECT_VER} Database

## Quick Start

\`\`\`bash
chmod +x start-clickhouse.sh stop-clickhouse.sh
./start-clickhouse.sh
\`\`\`

## Access

- HTTP: http://localhost:${CLICKHOUSE_HTTP_PORT:-8123}
- Native: localhost:${CLICKHOUSE_NATIVE_PORT:-9000}

## CLI

\`\`\`bash
clickhouse-client --host localhost --password ${PROJECT_NAME}_password
\`\`\`

## HTTP API

\`\`\`bash
curl http://localhost:8123/?query=SELECT%201
\`\`\`

## Commands

- **Start:** \`./start-clickhouse.sh\`
- **Stop:** \`./stop-clickhouse.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ClickHouse project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Version:    ${YELLOW}$SELECT_VER${NC}"
echo -e "  DBeaver:   ${YELLOW}$( [ "$dbeaver_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-clickhouse.sh stop-clickhouse.sh"
echo "3. ./start-clickhouse.sh"
echo ""
