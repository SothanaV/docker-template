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
    echo "Example: $0 my-traefik"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Traefik project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Traefik Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select SSL provider:${NC}"
echo "  1) Self-signed (default)"
echo "  2) Let's Encrypt"
read -p "  Enter choice [1]: " ssl_choice
ssl_choice="${ssl_choice:-1}"
case $ssl_choice in
    1) SELECT_SSL="none" ;;
    2) SELECT_SSL="letsencrypt" ;;
esac

echo -e "\n${YELLOW}Select dashboard:${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -p "  Enter choice [1]: " dash_choice
dash_choice="${dash_choice:-1}"

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
TRAEFIK_HTTP_PORT=80
TRAEFIK_HTTPS_PORT=443
TRAEFIK_DASHBOARD_PORT=8080
"

dockerfile_content="services:
    traefik:
        container_name: \${PROJECT_NAME}-proxy
        image: traefik:v3.1
        command:
            - \"--api.dashboard=true\"
            - \"--providers.docker=true\"
            - \"--providers.docker.exposedbydefault=false\"
            - \"--entrypoints.web.address=:80\"
"

if [ "$SELECT_SSL" = "letsencrypt" ]; then
    dockerfile_content+="            - \"--entrypoints.websecure.address=:443\"
            - \"--certificatesresolvers.letsencrypt.acme.httpchallenge=true\"
            - \"--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web\"
            - \"--certificatesresolvers.letsencrypt.acme.email=admin@${DOMAIN:-localhost}\"
            - \"--certificatesresolvers.letsencrypt.acme.storage=/acme.json\"
"
fi

dockerfile_content+=$'
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock:ro
            - ./config/traefik.yml:/etc/traefik/traefik.yml
            - ./acme.json:/acme.json
        ports:
            - "${TRAEFIK_HTTP_PORT}:80"
        networks:
            - proxy
        healthcheck:
            test: ["CMD", "traefik", "ping"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 10s
        restart: unless-stopped
'

if [ "$dash_choice" = "1" ]; then
    dockerfile_content+=$'
    dashboard:
        container_name: ${PROJECT_NAME}-dashboard
        image: swaggerapi/swagger-ui:latest
        ports:
            - "5051:8080"
        environment:
            SWAGGER_JSON_URL: http://traefik:8080/api/rawconfig
        depends_on:
            traefik:
                condition: service_healthy
        restart: unless-stopped
'
fi

dockerfile_content+=$'
networks:
    proxy:
        driver: bridge
'

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Traefik config
create_file "$PROJECT_DIR/config/traefik.yml" "log:
  level: INFO

api:
  dashboard: true
  insecure: ${SELECT_SSL =}

providers:
  docker:
    network: proxy
  file:
    directory: /etc/traefik/dynamic
    watch: true
"

# Acme file
create_file "$PROJECT_DIR/acme.json" "# SSL certificates stored here (permissions: chmod 600)"

# Docker labels file for documentation
create_file "$PROJECT_DIR/labels.example" "# Example Docker labels to use with Traefik
# Add these labels to your services:

# HTTP only
# labels:
#   - \"traefik.enable=true\"
#   - \"traefik.http.routers.${PROJECT_NAME}.rule=Host(\`app.localhost\`)\"
#   - \"traefik.http.routers.${PROJECT_NAME}.entrypoints=web\"
#   - \"traefik.http.services.${PROJECT_NAME}.loadbalancer.server.port=5000\"

# HTTPS + redirect to HTTP
# labels:
#   - \"traefik.enable=true\"
#   - \"traefik.http.routers.${PROJECT_NAME}.rule=Host(\`app.localhost\`)\"
#   - \"traefik.http.routers.${PROJECT_NAME}.entrypoints=websecure\"
#   - \"traefik.http.routers.${PROJECT_NAME}.tls=true\"
#   - \"traefik.http.routers.${PROJECT_NAME}.tls.certresolver=letsencrypt\"
#   - \"traefik.http.services.${PROJECT_NAME}.loadbalancer.server.port=5000\"
"

create_file "$PROJECT_DIR/.dockerignore" "acme.json
config/traefik.yml
*.log
.DS_Store
__pycache__/
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
acme.json
__pycache__/
"

create_file "$PROJECT_DIR/start-traefik.sh" "#!/bin/bash
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

echo \"Starting Traefik...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mTraefik started!\"
echo -e \"HTTP:      \033[1;33mlocalhost:\${TRAEFIK_HTTP_PORT:-80}\033[0m\"
echo -e \"Dashboard: \033[1;33mlocalhost:8080\033[0m\"
echo -e \"Logs:      \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:      \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-traefik.sh" "#!/bin/bash
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

echo \"Stopping Traefik...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-traefik.sh"
chmod +x "$PROJECT_DIR/stop-traefik.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Traefik v3.x Reverse Proxy

## Quick Start

\`\`\`bash
chmod +x start-traefik.sh stop-traefik.sh
./start-traefik.sh
\`\`\`

## Access

- HTTP: http://localhost:${TRAEFIK_HTTP_PORT:-80}
- Dashboard: http://localhost:8080

## Usage

Add these labels to your service containers:

\`\`\`yaml
labels:
  - \"traefik.enable=true\"
  - \"traefik.http.routers.myapp.rule=Host(\`app.localhost\`)\"
  - \"traefik.http.services.myapp.loadbalancer.server.port=5000\"
\`\`\`

## Commands

- **Start:** \`./start-traefik.sh\`
- **Stop:** \`./stop-traefik.sh\`
- **View API:** \`curl http://localhost:8080/api/http/routers\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Traefik project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  SSL:          ${YELLOW}$SELECT_SSL${NC}"
echo -e "  Dashboard:    ${YELLOW}$( [ "$dash_choice" = "1" ] && echo 'Yes' || echo 'No' )${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-traefik.sh stop-traefik.sh"
echo "3. ./start-traefik.sh"
echo ""
