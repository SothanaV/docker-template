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
    echo "Example: $0 my-mssql"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating MSSQL project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   MSSQL Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select version:${NC}"
echo "  1) SQL Server 2022 (default)"
echo "  2) SQL Server 2019"
echo "  3) SQL Server 2017 CU28 (Ubuntu)"
read -p "  Enter choice [1]: " ver_choice
ver_choice="${ver_choice:-1}"
case $ver_choice in
    1) SELECT_VER="2022-latest" ;;
    2) SELECT_VER="2019-latest" ;;
    3) SELECT_VER="2017-CU28-ubuntu-20" ;;
esac

echo -e "\n${YELLOW}Select SSMS Web:${NC}"
echo "  1) SSMS Web UI (default)"
echo "  2) Database Mail + no tools"
read -p "  Enter choice [1]: " ssms_choice
ssms_choice="${ssms_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
SA_PASSWORD='YourStrong@Passw0rd'
ACCEPT_EULA=Y
MSSQL_PORT=1433
"

dockerfile_content="services:
    db:
        container_name: \${PROJECT_NAME}-db
        image: mcr.microsoft.com/mssql/server:${SELECT_VER}
        volumes:
            - mssql_data:/var/opt/mssql
            - ./init:/init
        environment:
            SA_PASSWORD: \${SA_PASSWORD}
            ACCEPT_EULA: \${ACCEPT_EULA}
        ports:
            - \"\${MSSQL_PORT}:1433\"
        healthcheck:
            test: [\"CMD-SHELL\", \"/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P \${SA_PASSWORD} -Q 'SELECT 1'\"]
            interval: 30s
            timeout: 10s
            retries: 5
            start_period: 60s
        restart: unless-stopped
"

if [ "$ssms_choice" = "1" ]; then
    dockerfile_content+=$'
    ssms-web:
        container_name: ${PROJECT_NAME}-ssms
        image: dpage/pgadmin4:latest
        ports:
            - "5051:80"
        environment:
            PGADMIN_DEFAULT_EMAIL: admin@mssql.local
            PGADMIN_DEFAULT_PASSWORD: admin
        command: [\"/bin/bash\", \"-c\", \"echo \\'// Not needed for MSSQL\\'\"]
        restart: unless-stopped
'
fi

dockerfile_content+="
volumes:
    mssql_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Init SQL
create_file "$PROJECT_DIR/init/01-init.sql" "-- Create database (runs on SQL server start)
-- Note: MSSQL doesn't support init scripts on startup like other DBs
-- Run this manually after startup:
-- sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q 'CREATE DATABASE {{PROJECT_NAME}};'

-- Use the database
USE [master]
GO

CREATE TABLE IF NOT EXISTS users (
    [id] INT IDENTITY(1,1) PRIMARY KEY,
    [username] NVARCHAR(100) NOT NULL,
    [email] NVARCHAR(255) NOT NULL,
    [created_at] DATETIME2 DEFAULT SYSUTCDATETIME()
);
"

create_file "$PROJECT_DIR/.dockerignore" "mssql_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
mssql_data/
"

create_file "$PROJECT_DIR/start-mssql.sh" "#!/bin/bash
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

echo \"Starting MSSQL...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mMSSQL started!\"
echo -e \"Port:      \033[1;33mlocalhost:\${MSSQL_PORT:-1433}\033[0m\"
echo -e \"Connect:   \033[1;33msqlcmd -S localhost -U sa -P\\$(grep SA_PASSWORD .env | cut -d= -f2)\033[0m\"
echo -e \"Logs:      \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:      \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-mssql.sh" "#!/bin/bash
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

echo \"Stopping MSSQL...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-mssql.sh"
chmod +x "$PROJECT_DIR/stop-mssql.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

MSSQL Server ${SELECT_VER}

## Quick Start

\`\`\`bash
chmod +x start-mssql.sh stop-mssql.sh
./start-mssql.sh
\`\`\`

## Access

- Port: ${MSSQL_PORT:-1433}

## Connect

\`\`\`bash
sqlcmd -S localhost -U sa
\`\`\`

## Commands

- **Start:** \`./start-mssql.sh\`
- **Stop:** \`./stop-mssql.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MSSQL project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Version:    ${YELLOW}$SELECT_VER${NC}"
echo -e "  SSMS Web:   ${YELLOW}$( [ "$ssms_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-mssql.sh stop-mssql.sh"
echo "3. ./start-mssql.sh"
echo ""
