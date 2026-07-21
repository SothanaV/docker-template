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
    echo "Example: $0 my-postgres"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating PostgreSQL project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   PostgreSQL Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select version:${NC}"
echo "  1) PostgreSQL 16 (default)"
echo "  2) PostgreSQL 15"
echo "  3) PostgreSQL 14"
read -p "  Enter choice [1]: " ver_choice
ver_choice="${ver_choice:-1}"
case $ver_choice in
    1) PG_VER="16" ;;
    2) PG_VER="15" ;;
    3) PG_VER="14" ;;
esac

echo -e "\n${YELLOW}Select extensions:${NC}"
echo "  1) pgvector (default)"
echo "  2) postgis"
echo "  3) none"
read -p "  Enter choice [1]: " ext_choice
ext_choice="${ext_choice:-1}"
case $ext_choice in
    1) SELECT_EXT="pgvector" ;;
    2) SELECT_EXT="postgis" ;;
    3) SELECT_EXT="none" ;;
esac

echo -e "\n${YELLOW}Select pgAdmin:${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -p "  Enter choice [1]: " pgadmin_choice
pgadmin_choice="${pgadmin_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
POSTGRES_DB='${PROJECT_NAME}_db'
POSTGRES_USER='${PROJECT_NAME}_user'
POSTGRES_PASSWORD='${PROJECT_NAME}_password'
POSTGRES_PORT=5432
"

# Build docker-compose with optional pgvector/postgis
dockerfile_content="services:
    db:
        container_name: \${PROJECT_NAME}-db
"

if [ "$SELECT_EXT" = "pgvector" ]; then
    dockerfile_content+="        image: pgvector/pgvector:pg${PG_VER}
"
elif [ "$SELECT_EXT" = "postgis" ]; then
    dockerfile_content+="        image: postgis/postgis:${PG_VER}-latest
"
else
    dockerfile_content+="        image: postgres:${PG_VER}-alpine
"
fi

dockerfile_content+=$'
        volumes:
            - postgres_data:/var/lib/postgresql/data
            - ./init:/docker-entrypoint-initdb.d
        environment:
            POSTGRES_DB: ${POSTGRES_DB}
            POSTGRES_USER: ${POSTGRES_USER}
            POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
        ports:
            - "${POSTGRES_PORT}:5432"
        healthcheck:
            test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 30s
        restart: unless-stopped
'

if [ "$pgadmin_choice" = "1" ]; then
    dockerfile_content+=$'
    pgadmin:
        container_name: ${PROJECT_NAME}-pgadmin
        image: dpage/pgadmin4:latest
        ports:
            - "5051:80"
        environment:
            PGADMIN_DEFAULT_EMAIL: admin@postgres.local
            PGADMIN_DEFAULT_PASSWORD: admin
        depends_on:
            db:
                condition: service_healthy
        restart: unless-stopped
'
fi

dockerfile_content+="
volumes:
    postgres_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Init SQL file
create_file "$PROJECT_DIR/init/01-init.sql" "-- Create tables
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample data
INSERT INTO users (username, email) VALUES
    ('admin', 'admin@${PROJECT_NAME}.local'),
    ('user1', 'user1@${PROJECT_NAME}.local');
"

create_file "$PROJECT_DIR/.dockerignore" "docker-compose*.yml
*.yml !docker-compose.yml
init/*.sql
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
"

create_file "$PROJECT_DIR/start-postgresql.sh" "#!/bin/bash
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

echo \"Starting PostgreSQL...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mPostgreSQL started!\"
echo -e \"Port:    \033[1;33mlocalhost:\${POSTGRES_PORT:-5432}\033[0m\"
echo -e \"padmin:  \033[1;33mlocalhost:5051\033[0m (if enabled)\"
echo -e \"Connect: \033[1;33mpsql -h localhost -p \${POSTGRES_PORT:-5432} -U \${POSTGRES_USER:-${PROJECT_NAME}_user}\033[0m\"
echo -e \"Logs:    \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:    \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-postgresql.sh" "#!/bin/bash
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

echo \"Stopping PostgreSQL...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-postgresql.sh"
chmod +x "$PROJECT_DIR/stop-postgresql.sh"

# README
create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

PostgreSQL ${PG_VER} Database

## Quick Start

\`\`\`bash
chmod +x start-postgresql.sh stop-postgresql.sh
./start-postgresql.sh
\`\`\`

## Configuration

Edit \`\.env\` to change passwords and ports.

## pgAdmin (if enabled)

- URL: http://localhost:5051
- Email: admin@postgres.local
- Password: admin

## Connect

\`\`\`bash
psql -h localhost -U ${PROJECT_NAME}_user -d ${PROJECT_NAME}_db
\`\`\`

## Access

- Port: ${POSTGRES_PORT:-5432}
- Database: ${POSTGRES_DB:-${PROJECT_NAME}_db}
- User: ${POSTGRES_USER:-${PROJECT_NAME}_user}

## Commands

- **Start:** \`./start-postgresql.sh\`
- **Stop:** \`./stop-postgresql.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PostgreSQL project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Version:       ${YELLOW}$PG_VER${NC}"
echo -e "  Extension:     ${YELLOW}$SELECT_EXT${NC}"
echo -e "  pgAdmin:       ${YELLOW}$( [ "$pgadmin_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-postgresql.sh stop-postgresql.sh"
echo "3. ./start-postgresql.sh"
echo ""
