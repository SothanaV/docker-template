#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-flask-app"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Flask project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

# Interactive Feature Menu
echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Flask Project Features${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select database:${NC}"
echo "  1) PostgreSQL (default)"
echo "  2) MySQL"
echo "  3) SQLite"
read -p "  Enter choice [1]: " db_choice
db_choice="${db_choice:-1}"
case $db_choice in
    1) SELECT_DATABASE="postgresql" ;;
    2) SELECT_DATABASE="mysql" ;;
    3) SELECT_DATABASE="sqlite" ;;
esac

echo -e "\n${YELLOW}Select auth:${NC}"
echo "  1) JWT (default)"
echo "  2) Token auth"
echo "  3) None"
read -p "  Enter choice [1]: " auth_choice
auth_choice="${auth_choice:-1}"
case $auth_choice in
    1) SELECT_AUTH="jwt" ;;
    2) SELECT_AUTH="token" ;;
    3) SELECT_AUTH="none" ;;
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
PYTHONUNBUFFERED=1

# Database
FLASK_ENV=development
DB_URL=postgresql://${PROJECT_NAME}_user:${PROJECT_NAME}_password@db:5432/${PROJECT_NAME}_db

# JWT (optional)
# JWT_SECRET_KEY=change-me-in-production
# JWT_ACCESS_TOKEN_EXPIRES_MINUTES=30
# JWT_REFRESH_TOKEN_EXPIRES_DAYS=7
"

create_file "$PROJECT_DIR/docker-compose.yml" "services:
    backend:
        container_name: \${PROJECT_NAME}-backend
        build: ./backend
        command: sh run-server-dev.sh
        volumes:
            - ./backend:/backend
        ports:
            - \"5050:5000\"
        env_file:
            - .env
        healthcheck:
            test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:5000/healthz\"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 40s
        restart: unless-stopped
"

if [ "$SELECT_DATABASE" != "sqlite" ]; then
    dockerfile_add="
    db:
        container_name: \${PROJECT_NAME}-db
"
    if [ "$SELECT_DATABASE" = "postgresql" ]; then
        dockerfile_add+="        image: postgres:16-alpine
"
        dockerfile_add+="        volumes:
            - postgres_data:/var/lib/postgresql/data
"
        dockerfile_add+="        environment:
            POSTGRES_DB: \${DB_NAME:-${PROJECT_NAME}_db}
            POSTGRES_USER: \${DB_USER:-${PROJECT_NAME}_user}
            POSTGRES_PASSWORD: \${DB_PASSWORD:-${PROJECT_NAME}_password}
"
        dockerfile_add+="        healthcheck:
            test: [\"CMD-SHELL\", \"pg_is-ready -U \${DB_USER} -d \${DB_NAME}\"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 30s
"
    elif [ "$SELECT_DATABASE" = "mysql" ]; then
        dockerfile_add+="        image: mysql:8.0
"
        dockerfile_add+="        volumes:
            - mysql_data:/var/lib/mysql
"
        dockerfile_add+="        environment:
            MYSQL_DATABASE: \${DB_NAME:-${PROJECT_NAME}_db}
            MYSQL_USER: \${DB_USER:-${PROJECT_NAME}_user}
            MYSQL_PASSWORD: \${DB_PASSWORD:-${PROJECT_NAME}_password}
            MYSQL_ROOT_PASSWORD: root
"
        dockerfile_add+="        healthcheck:
            test: [\"CMD\", \"mysqladmin\", \"ping\", \"-h\", \"localhost\"]
            interval: 10s
            timeout: 5s
            retries: 5
"
    fi
    dockerfile_add+="        depends_on:
            backend:
                condition: service_healthy
        restart: unless-stopped
"
    echo "$dockerfile_add" >> "$PROJECT_DIR/docker-compose.yml"
fi

create_file "$PROJECT_DIR/backend/Dockerfile" "FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc-dev libpq-dev libmariadb-dev curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /backend
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
"

create_file "$PROJECT_DIR/backend/__init__.py" "from flask import Flask

def create_app():
    app = Flask(__name__)
    app.config.from_prefixed_env()

    from blueprints.api import api_bp
    app.register_blueprint(api_bp, url_prefix='/api')

    return app
"

create_file "$PROJECT_DIR/backend/scaffold.py" "from create_app import create_app
app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
"

create_file "$PROJECT_DIR/backend/run-server.sh" "#!/bin/bash
set -e

n_workers=\${1:-4}
echo \"Starting gunicorn with \$n_workers workers...\"
gunicorn -w \$n_workers -b 0.0.0.0:5000 scaffold:app
"

create_file "$PROJECT_DIR/backend/run-server-dev.sh" "#!/bin/bash
set -e
FLASK_APP=scaffold.py flask run --host=0.0.0.0 --port=5000
"

# Blueprints
mkdir -p "$PROJECT_DIR/backend/blueprints/api"
create_file "$PROJECT_DIR/backend/blueprints/api/__init__.py" "from flask import Blueprint
from . import views

api_bp = Blueprint('api', __name__)

from . import views
"

create_file "$PROJECT_DIR/backend/blueprints/api/views.py" "from flask import jsonify, current_app
from . import api_bp

@api_bp.route('/hello/', methods=['GET'])
def hello():
    return jsonify({'message': 'Hello from Flask!', 'project': current_app.config.get('PROJECT_NAME', 'Flask')})

@api_bp.route('/healthz', methods=['GET'])
def healthz():
    status = {'status': 'ok', 'service': 'flask'}
    return jsonify(status)
"

# Requirements
base_packages = """flask==3.0.2
gunicorn==21.2.0
python-dotenv==1.0.1
"""

if SELECT_DATABASE == "postgresql":
    base_packages += "flask-sqlalchemy==3.1.1\npsycopg2-binary==2.9.9\n"
elif SELECT_DATABASE == "mysql":
    base_packages += "flask-sqlalchemy==3.1.1\nmysqlclient==2.2.1\n"
else:
    base_packages += "flask-sqlalchemy==3.1.1\n"

if SELECT_AUTH == "jwt":
    base_packages += "flask-jwt-extended==4.6.0\n"

create_file "$PROJECT_DIR/backend/requirements.txt", base_packages

create_file "$PROJECT_DIR/.dockerignore" """*.py[cod]
__pycache__/
.env
venv/
.venv/
*.egg-info/

.vscode/
.idea/

.DS_Store

*.log
logs/

.git/
"""

create_file "$PROJECT_DIR/.gitignore" """__pycache__/
*.py[cod]
.env
venv/
.venv/

.vscode/
.idea/

.DS_Store

*.log
"""

create_file "$PROJECT_DIR/start-flask.sh" "#!/bin/bash
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

echo \"Starting Flask services...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mServices started!\"
echo -e \"Backend: \033[1;33mhttp://localhost:5050\033[0m\"
echo -e \"Health:  \033[1;33mhttp://localhost:5050/healthz\033[0m\"
echo -e \"API:     \033[1;33mhttp://localhost:5050/api/hello/\033[0m\"
echo -e \"Logs:    \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:    \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-flask.sh" "#!/bin/bash
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

echo \"Stopping Flask services...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/backend/run-server.sh"
chmod +x "$PROJECT_DIR/backend/run-server-dev.sh"
chmod +x "$PROJECT_DIR/start-flask.sh"
chmod +x "$PROJECT_DIR/stop-flask.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Flask project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Features selected:"
echo -e "  Database:  ${YELLOW}$SELECT_DATABASE${NC}"
echo -e "  Auth:      ${YELLOW}$SELECT_AUTH${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-flask.sh stop-flask.sh"
echo "3. ./start-flask.sh"
echo "4. Open http://localhost:5050/api/hello/"
echo ""
