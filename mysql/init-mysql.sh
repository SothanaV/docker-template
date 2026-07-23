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
    echo "Example: $0 my-mysql"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating MySQL project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   MySQL Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select version:${NC}"
echo "  1) MySQL 8.0 (default)"
echo "  2) MySQL 8.4 LTS"
echo "  3) MariaDB 11"
read -p "  Enter choice [1]: " ver_choice
ver_choice="${ver_choice:-1}"
case $ver_choice in
    1) SELECT_VER="8.0" ; IMAGE="mysql" ;;
    2) SELECT_VER="8.4" ; IMAGE="mysql" ;;
    3) SELECT_VER="11"  ; IMAGE="mariadb" ;;
esac

echo -e "\n${YELLOW}Select tools:${NC}"
echo "  1) phpMyAdmin (default)"
echo "  2) Adminer"
echo "  3) None"
read -p "  Enter choice [1]: " tool_choice
tool_choice="${tool_choice:-1}"
case $tool_choice in
    1) SELECT_TOOL="phpmyadmin" ;;
    2) SELECT_TOOL="adminer" ;;
    3) SELECT_TOOL="none" ;;
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
MYSQL_ROOT_PASSWORD='root_password_change_me'
MYSQL_DATABASE='${PROJECT_NAME}_db'
MYSQL_USER='${PROJECT_NAME}_user'
MYSQL_PASSWORD='${PROJECT_NAME}_password'
MYSQL_PORT=3306
"

dockerfile_content="services:
    db:
        container_name: \${PROJECT_NAME}-db
        image: ${IMAGE}:${SELECT_VER}
        environment:
            MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
            MYSQL_DATABASE: \${MYSQL_DATABASE}
            MYSQL_USER: \${MYSQL_USER}
            MYSQL_PASSWORD: \${MYSQL_PASSWORD}
        volumes:
            - mysql_data:/var/lib/mysql
            - ./init:/docker-entrypoint-initdb.d
        ports:
            - \"\${MYSQL_PORT}:3306\"
        healthcheck:
            test: [\"CMD\", \"mysqladmin\", \"ping\", \"-h\", \"localhost\"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 30s
        restart: unless-stopped
"

if [ "$SELECT_TOOL" = "phpmyadmin" ]; then
    dockerfile_content+=$'
    phpmyadmin:
        container_name: ${PROJECT_NAME}-phpmyadmin
        image: phpmyadmin:latest
        ports:
            - "5051:80"
        environment:
            PMA_HOST: db
            PMA_PORT: 3306
        depends_on:
            db:
                condition: service_healthy
        restart: unless-stopped
'
elif [ "$SELECT_TOOL" = "adminer" ]; then
    dockerfile_content+=$'
    adminer:
        container_name: ${PROJECT_NAME}-adminer
        image: adminer:latest
        ports:
            - "5051:8080"
        depends_on:
            db:
                condition: service_healthy
        restart: unless-stopped
'
fi

dockerfile_content+="
volumes:
    mysql_data:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Init SQL
create_file "$PROJECT_DIR/init/01-init.sql" "-- Create tables
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username, email) VALUES
    ('admin', 'admin@${PROJECT_NAME}.local'),
    ('user1', 'user1@${PROJECT_NAME}.local');
"

create_file "$PROJECT_DIR/.dockerignore" "docker-compose*.yml
*.yml !docker-compose.yml
*_data/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
*_data/
"

create_file "$PROJECT_DIR/start-mysql.sh" "#!/bin/bash
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

echo \"Starting MySQL...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mMySQL started!\"
echo -e \"Port:       \033[1;33mlocalhost:\${MYSQL_PORT:-3306}\033[0m\"
echo -e \"phpMyAdmin: \033[1;33mlocalhost:5051\033[0m (if enabled)\"
echo -e \"Connect:    \033[1;33mmysql -h localhost -u ${MYSQL_USER:-${PROJECT_NAME}_user} -p\033[0m\"
echo -e \"Logs:       \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:       \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-mysql.sh" "#!/bin/bash
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

echo \"Stopping MySQL...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-mysql.sh"
chmod +x "$PROJECT_DIR/stop-mysql.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

MySQL ${SELECT_VER} Database

## Quick Start

\`\`\`bash
chmod +x start-mysql.sh stop-mysql.sh
./start-mysql.sh
\`\`\`

## Access

- Port: ${MYSQL_PORT:-3306}
- Database: ${MYSQL_DATABASE:-${PROJECT_NAME}_db}
- User: ${MYSQL_USER:-${PROJECT_NAME}_user}

## phpMyAdmin (if enabled)

- URL: http://localhost:5051

## Commands

- **Start:** \`./start-mysql.sh\`
- **Stop:** \`./stop-mysql.sh\`
- **Reset data:** \`docker compose down -v && docker compose up\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MySQL project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  Version:  ${YELLOW}${SELECT_VER} ($IMAGE)${NC}"
echo -e "  Tools:    ${YELLOW}$SELECT_TOOL${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-mysql.sh stop-mysql.sh"
echo "3. ./start-mysql.sh"
echo ""
