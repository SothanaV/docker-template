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
    echo "Example: $0 my-oracle"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Oracle project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Oracle Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select edition:${NC}"
echo "  1) Oracle Express 23c (default)"
echo "  2) Oracle Express 21c"
read -p "  Enter choice [1]: " ed_choice
ed_choice="${ed_choice:-1}"
case $ed_choice in
    1) SELECT_ED="oracle-xe-23c" ; ORACLE_VER="23c" ;;
    2) SELECT_ED="oracle-xe-21c" ; ORACLE_VER="21c" ;;
esac

echo -e "\n${YELLOW}Select Oracle SQL Developer Web:${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -p "  Enter choice [1]: " dev_choice
dev_choice="${dev_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
ORACLE_PWD='Oracle123!'
ORACLE_CHARACTERSET=AL32UTF8
ORACLE_PORT=1521
"

dockerfile_content="services:
    db:
        container_name: \${PROJECT_NAME}-db
        image: container-registry.oracle.com/database/express:${SELECT_ED}
        volumes:
            - oracle_data:/opt/oracle/oradata
        environment:
            ORACLE_PWD: \${ORACLE_PWD}
            ORACLE_CHARACTERSET: \${ORACLE_CHARACTERSET}
        ports:
            - \"\${ORACLE_PORT}:1521\"
        healthcheck:
            test: [\"CMD\", \"bash\", \"-c\", \"cat < /dev/null > /dev/tcp/localhost/1521\"]
            interval: 30s
            timeout: 10s
            retries: 5
            start_period: 120s
        restart: unless-stopped
"

if [ "$dev_choice" = "1" ]; then
    dockerfile_content+=$'
    oracle-web:
        container_name: ${PROJECT_NAME}-oracle-web
        image: omssys/sql-developer:latest
        ports:
            - "5051:5050"
        depends_on:
            db:
                condition: service_healthy
        restart: unless-stopped
'
fi

dockerfile_content+="
volumes:
    oracle_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

create_file "$PROJECT_DIR/.dockerignore" "oracle_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
oracle_data/
"

create_file "$PROJECT_DIR/start-oracle.sh" "#!/bin/bash
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

echo \"Starting Oracle...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mOracle started!\"
echo -e \"Port:       \033[1;33mlocalhost:\${ORACLE_PORT:-1521}\033[0m\"
echo -e \"Web UI:     \033[1;33mlocalhost:5051\033[0m (if enabled)\"
echo -e \"PDB:        \033[1;33m${PROJECT_NAME}_xepdb1\033[0m\"
echo -e \"Logs:       \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:       \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-oracle.sh" "#!/bin/bash
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

echo \"Stopping Oracle...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-oracle.sh"
chmod +x "$PROJECT_DIR/stop-oracle.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Oracle ${ORACLE_VER} Express

## Quick Start

\`\`\`bash
chmod +x start-oracle.sh stop-oracle.sh
./start-oracle.sh
\`\`\`

## Access

- Port: ${ORACLE_PORT:-1521}
- PDB: ${PROJECT_NAME}_xepdb1
- System Password: ${ORACLE_PWD:-Oracle123!}

## SQL Developer Web (if enabled)

- URL: http://localhost:5051

## Commands

- **Start:** \`./start-oracle.sh\`
- **Stop:** \`./stop-oracle.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`

## Note

Oracle takes 2-3 minutes to start. Be patient!
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Oracle project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Edition:    ${YELLOW}$SELECT_ED${NC}"
echo -e "  SQL Dev:    ${YELLOW}$( [ "$dev_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-oracle.sh stop-oracle.sh"
echo "3. ./start-oracle.sh"
echo "4. Wait 2-3 minutes for startup"
echo ""
