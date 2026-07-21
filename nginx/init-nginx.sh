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
    echo "Example: $0 my-nginx"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Nginx project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Nginx Options${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select SSL:${NC}"
echo "  1) Self-signed cert (default)"
echo "  2) Let's Encrypt (certbot)"
read -p "  Enter choice [1]: " ssl_choice
ssl_choice="${ssl_choice:-1}"
case $ssl_choice in
    1) SELECT_SSL="self-signed" ;;
    2) SELECT_SSL="letsencrypt" ;;
esac

echo -e "\n${YELLOW}Select features:${NC}"
echo "  1) Basic web server (default)"
echo "  2) Reverse proxy + load balancer"
read -p "  Enter choice [1]: " feat_choice
feat_choice="${feat_choice:-1}"
case $feat_choice in
    1) SELECT_FEA="basic" ;;
    2) SELECT_FEA="reverse-proxy" ;;
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
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
DOMAIN=localhost
"

# Build docker-compose
dockerfile_content="services:
    nginx:
        container_name: \${PROJECT_NAME}-nginx
        image: nginx:${NGINX_VER:-1.25-alpine}
"

dockerfile_content+=$'
        volumes:
            - ./config/nginx.conf:/etc/nginx/conf.d/default.conf
            - ./certs:/etc/nginx/certs:ro
            - static:/app/static
            - media:/app/media
        ports:
            - "${NGINX_HTTP_PORT}:80"
'

if [ "$SELECT_SSL" = "self-signed" ]; then
    dockerfile_content+=$'
            - "${NGINX_HTTPS_PORT}:443"
'
fi

dockerfile_content+=$'
        healthcheck:
            test: ["CMD-SHELL", "curl -f http://localhost:80/ || exit 1"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 10s
        restart: unless-stopped
'

dockerfile_content+="
volumes:
    static:
    media:
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# Nginx config - basic
if [ "$SELECT_SSL" = "self-signed" ]; then
    create_file "$PROJECT_DIR/config/nginx.conf" "server {
    listen 80;
    server_name ${DOMAIN:-localhost};

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://backend:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static {
        alias /app/static;
        expires 30d;
        add_header Cache-Control \"public, immutable\";
    }

    location /media {
        alias /app/media;
        expires 7d;
    }
}
"
else
    create_file "$PROJECT_DIR/config/nginx.conf" "server {
    listen 80;
    server_name ${DOMAIN:-localhost};

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN:-localhost};

    ssl_certificate /etc/nginx/certs/${DOMAIN:-localhost}.crt;
    ssl_certificate_key /etc/nginx/certs/${DOMAIN:-localhost}.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://backend:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static {
        alias /app/static;
        expires 30d;
        add_header Cache-Control \"public, immutable\";
    }

    location /media {
        alias /app/media;
        expires 7d;
    }
}
"
fi

# Create sample www files
create_file "$PROJECT_DIR/www/index.html" "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <title>${PROJECT_NAME}</title>
</head>
<body>
    <h1>Welcome to ${PROJECT_NAME}</h1>
</body>
</html>
"

create_file "$PROJECT_DIR/certs/.gitkeep" "# placeholder for SSL certs"

create_file "$PROJECT_DIR/static/.gitkeep" "# placeholder for static files"
create_file "$PROJECT_DIR/media/.gitkeep" "# placeholder for media files"

create_file "$PROJECT_DIR/.dockerignore" "certs/
static/
media/
www/
*.log
.DS_Store
"

create_file "$PROJECT_DIR/.gitignore" "*.log
.env
.DS_Store
certs/*.crt
certs/*.key
certs/*.pem
"

create_file "$PROJECT_DIR/start-nginx.sh" "#!/bin/bash
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

echo \"Starting Nginx...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mNginx started!\"
echo -e \"HTTP:   \033[1;33mlocalhost:\${NGINX_HTTP_PORT:-80}\033[0m\"
if [ \"\$SELECT_SSL\" = \"self-signed\" ]; then
    echo -e \"HTTPS:  \033[1;33mlocalhost:\${NGINX_HTTPS_PORT:-443}\033[0m\"
fi
echo -e \"Logs:   \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:   \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-nginx.sh" "#!/bin/bash
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

echo \"Stopping Nginx...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-nginx.sh"
chmod +x "$PROJECT_DIR/stop-nginx.sh"

create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Nginx ${NGINX_VER:-1.25} Web Server

## Quick Start

\`\`\`bash
chmod +x start-nginx.sh stop-nginx.sh
./start-nginx.sh
\`\`\`

## Access

- HTTP: http://localhost:${NGINX_HTTP_PORT:-80}
${SELECT_SSL:='HTTPS': http://localhost:${NGINX_HTTPS_PORT:-443}}

## Structure

- Config: \`./config/nginx.conf\`
- Static: \`./static/\`
- Media: \`./media/\`

## Commands

- **Start:** \`./start-nginx.sh\`
- **Stop:** \`./stop-nginx.sh\`
- **Test config:** \`docker compose exec nginx nginx -t\`
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Nginx project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Options selected:"
echo -e "  SSL:          ${YELLOW}$SELECT_SSL${NC}"
echo -e "  Features:     ${YELLOW}$SELECT_FEA${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-nginx.sh stop-nginx.sh"
echo "3. ./start-nginx.sh"
echo ""
