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
    echo "Example: $0 my-redis"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Redis project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Redis Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select edition:${NC}"
echo "  1) Redis 7 (default)"
echo "  2) Redis Stack (with JSON, Vector, Search)"
echo "  3) Valkey (Linux Foundation)"
read -p "  Enter choice [1]: " ed_choice
ed_choice="${ed_choice:-1}"
case $ed_choice in
    1) SELECT_ED="redis:7-alpine" ; IMG_TYPE="redis" ;;
    2) SELECT_ED="redis/redis-stack:latest" ; IMG_TYPE="redis-stack" ;;
    3) SELECT_ED="valkey/valkey:7-alpine" ; IMG_TYPE="valkey" ;;
esac

echo -e "\n${YELLOW}Select ACL:${NC}"
echo "  1) Disable (default)"
echo "  2) Enable ACL"
read -p "  Enter choice [1]: " acl_choice
acl_choice="${acl_choice:-1}"

echo -e "\n${YELLOW}Select Redis Commander (web UI):${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -p "  Enter choice [1]: " rc_choice
rc_choice="${rc_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
REDIS_PASSWORD=''
REDIS_PORT=6379
REDIS_MAX_MEMORY=256mb
REDIS_MAX_MEMORY_POLICY=allkeys-lru
"

# Build docker-compose
dockerfile_content="services:
    redis:
        container_name: \${PROJECT_NAME}-redis
        image: ${SELECT_ED}
        volumes:
            - redis_data:/data
"

if [ "$acl_choice" = "2" ]; then
    create_file "$PROJECT_DIR/redis.conf" "# Redis Configuration
maxmemory $REDIS_MAX_MEMORY
maxmemory-policy allkeys-lru
requirepass ${PROJECT_NAME}_redis_password
"
    dockerfile_content+=$'
        volumes:
            - redis_data:/data
            - ./redis.conf:/usr/local/etc/redis/redis.conf
        command: [\"redis-server\", \"/usr/local/etc/redis/redis.conf\"]
'
fi

dockerfile_content+=$'
        ports:
            - "${REDIS_PORT}:6379"
        healthcheck:
            test: ["CMD", "redis-cli", "ping"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 10s
        restart: unless-stopped
'

if [ "$rc_choice" = "1" ]; then
    dockerfile_content+=$'
    redis-commander:
        container_name: ${PROJECT_NAME}-redis-commander
        image: rediscommander/redis-commander:latest
        environment:
            REDIS_HOSTS: local:redis:6379
        ports:
            - "5051:8081"
        depends_on:
            redis:
                condition: service_healthy
        restart: unless-stopped
'
fi

dockerfile_content+="
volumes:
    redis_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

create_file "$PROJECT_DIR/.dockerignore" "redis_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
redis_data/
"

create_file "$PROJECT_DIR/start-redis.sh" "#!/bin/bash
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

echo \"Starting Redis...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mRedis started!\"
echo -e \"Port:     \033[1;33mlocalhost:\${REDIS_PORT:-6379}\033[0m\"
echo -e \"UI:       \033[1;33mlocalhost:5051\033[0m (if enabled)\"
echo -e \"CLI:      \033[1;33mredis-cli -h localhost\033[0m\"
echo -e \"Logs:     \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:     \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-redis.sh" "#!/bin/bash
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

echo \"Stopping Redis...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-redis.sh"
chmod +x "$PROJECT_DIR/stop-redis.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Redis Database

## Quick Start

\`\`\`bash
chmod +x start-redis.sh stop-redis.sh
./start-redis.sh
\`\`\`

## Access

- Port: ${REDIS_PORT:-6379}
- CLI: redis-cli -h localhost

## Redis Commander (if enabled)

- URL: http://localhost:5051

## CLI

\`\`\`bash
redis-cli -h localhost -p ${REDIS_PORT:-6379} ping
\`\`\`

## Commands

- **Start:** \`./start-redis.sh\`
- **Stop:** \`./stop-redis.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Redis project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Edition:   ${YELLOW}$IMG_TYPE${NC}"
echo -e "  ACL:       ${YELLOW}$( [ "$acl_choice" = "2" ] && echo 'Enabled' || echo 'Disabled' )${NC}"
echo -e "  Commander: ${YELLOW}$( [ "$rc_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-redis.sh stop-redis.sh"
echo "3. ./start-redis.sh"
echo ""
