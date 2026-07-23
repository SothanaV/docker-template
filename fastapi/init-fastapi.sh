#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-api"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating FastAPI project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

# Create directory structure
mkdir -p "$PROJECT_DIR/backend"

# Function to write file
create_file() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

# Create .env
create_file "$PROJECT_DIR/.env" "# FastAPI Environment Configuration
PROJECT_NAME=\"$PROJECT_NAME\"
PYTHONUNBUFFERED=1

# Database Configuration (optional)
# DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/$PROJECT_NAME
# DB_USER=postgres
# DB_PASSWORD=postgres
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=$PROJECT_NAME

# Redis Configuration (optional)
# REDIS_URL=redis://localhost:6379/0

# Server Configuration
# PORT=5000
"

# Create docker-compose.yml
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

# Create backend/Dockerfile
create_file "$PROJECT_DIR/backend/Dockerfile" "FROM python:3.14-slim

RUN apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends \
        git netcat-traditional curl iputils-ping dnsutils && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /backend
ADD ./requirements.txt requirements.txt
RUN pip install -r requirements.txt
ADD . /backend/
WORKDIR /backend
"

# Create backend/server.py
create_file "$PROJECT_DIR/backend/server.py" "# FastAPI Application

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import os
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

app = FastAPI(
    title=os.getenv('PROJECT_NAME', 'FastAPI App'),
    description='FastAPI Application',
    version='1.0.0'
)


@app.get('/')
def read_root():
    return {'Hello': 'World', 'Project': os.getenv('PROJECT_NAME', 'FastAPI')}


@app.get('/healthz')
async def healthz():
    status = {'status': 'healthy', 'service': 'fastapi'}

    # Check PostgreSQL
    try:
        from sqlalchemy import create_engine
        import sqlalchemy
        db_url = os.getenv(\"DATABASE_URL\", os.getenv('SQLALCHEMY_DATABASE_URI', ''))
        if db_url:
            engine = create_engine(db_url)
            with engine.connect() as conn:
                conn.execute(sqlalchemy.text('SELECT 1'))
            status['postgresql'] = 'connected'
        else:
            status['postgresql'] = 'no-config'
    except Exception as e:
        status['postgresql'] = f'disconnected: {str(e)}'
        status['status'] = 'degraded'

    # Check Redis
    try:
        import redis
        redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
        r = redis.from_url(redis_url)
        r.ping()
        status['redis'] = 'connected'
    except Exception as e:
        status['redis'] = f'disconnected: {str(e)}'
        status['status'] = 'degraded'

    code = 503 if status['status'] != 'healthy' else 200
    return JSONResponse(content=status, status_code=code)


# Example endpoints
@app.get('/api/v1/hello/{name}')
def say_hello(name: str):
    return {'message': f'Hello {name}!', 'project': os.getenv('PROJECT_NAME', 'FastAPI')}


@app.post('/api/v1/data')
def create_data(data: dict):
    return {'status': 'created', 'data': data}
"

# Create backend/run-server.sh
create_file "$PROJECT_DIR/backend/run-server.sh" "#!/bin/bash
set -e

n_workers=\${1:-4}
root_path=\${2:-}

# Remove leading slash to avoid double slashes
root_path=\"\${root_path#/}\"

echo \"n_workers=\$n_workers\"
echo \"root_path=\$root_path\"
echo \"Starting uvicorn with \$n_workers workers...\"

uvicorn --log-config log-config.yaml --workers=\"\$n_workers\" --log-level debug --host 0.0.0.0 --port 5000 server:app --root-path \"\${root_path}\"
"

# Create backend/run-server-dev.sh
create_file "$PROJECT_DIR/backend/run-server-dev.sh" "#!/bin/bash
set -e

root_path=\${1:-/}

# Remove leading slash to avoid double slashes
root_path=\"\${root_path#/}\"

uvicorn --log-config log-config.yaml --reload --log-level debug --host 0.0.0.0 --port 5000 server:app --root-path \"\${root_path}\"
"

# Create backend/log-config.yaml
create_file "$PROJECT_DIR/backend/log-config.yaml" "version: 1
formatters:
  default:
    format: \"%(asctime)s | %(levelname)s | %(name)s | %(message)s\"
handlers:
  default:
    class: logging.StreamHandler
    formatter: default
    stream: ext://sys.stdout
loggers:
  uvicorn:
    handlers: [default]
    level: INFO
    propagate: no
  uvicorn.error:
    level: INFO
    handlers: [default]
    propagate: no
  uvicorn.access:
    level: INFO
    handlers: [default]
    propagate: no
root:
  level: INFO
  handlers: [default]
"

# Create backend/requirements.txt
create_file "$PROJECT_DIR/backend/requirements.txt" "fastapi==0.111.0
uvicorn[standard]==0.29.0
python-dotenv==1.0.1
pydantic==2.7.1
sqlalchemy==2.0.28
alembic==1.13.1
pymysql==1.1.0
redis==5.0.4
httpx==0.27.0
orjson==3.10.3
pyyaml==6.0.1
"

# Create backend/requirements-dev.txt
create_file "$PROJECT_DIR/backend/requirements-dev.txt" "fastapi==0.111.0
uvicorn[standard]==0.29.0
python-dotenv==1.0.1
pydantic==2.7.1
sqlalchemy==2.0.28
alembic==1.13.1
pymysql==1.1.0
redis==5.0.4
httpx==0.27.0
orjson==3.10.3
pyyaml==6.0.1

# Development tools
pytest==7.4.4
pytest-asyncio==0.23.5
black==24.2.0
isort==5.13.2
flake8==7.0.0
mypy==1.8.0
"

# Create start-all-fastapi.sh
create_file "$PROJECT_DIR/start-all-fastapi.sh" "#!/bin/bash
set -e

SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"
cd \"\$SCRIPT_DIR\"

echo \"Starting FastAPI services...\"

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo \"Error: docker is not installed or not in PATH\"
    exit 1
fi

# Determine which docker compose command to use
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker compose\"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker-compose\"
else
    echo \"Error: docker-compose (or 'docker compose') is not installed or not in PATH\"
    exit 1
fi

echo \"Using: \$COMPOSE_CMD\"
echo \"Starting services in detached mode...\"

# Stop existing containers if running
echo \"Stopping existing services...\"
\$COMPOSE_CMD down 2>/dev/null || true

# Build and start services
echo \"Building and starting services...\"
\$COMPOSE_CMD up --build -d

# Wait for service to be healthy
echo \"Waiting for backend to be healthy...\"
\$COMPOSE_CMD ps

echo \"\"
echo -e \"\033[0;32mServices started successfully!\033[0m\"
echo -e \"Backend: \033[1;33mhttp://localhost:5050\033[0m\"
echo -e \"Health check: \033[1;33mhttp://localhost:5050/healthz\033[0m\"
echo -e \"API docs: \033[1;33mhttp://localhost:5050/docs\033[0m\"
echo \"\"
echo -e \"View logs: \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop: \033[1;33m\$COMPOSE_CMD down\033[0m\"
echo -e \"Restart: \033[1;33m\$COMPOSE_CMD restart\033[0m\"
"

# Create stop-all-fastapi.sh
create_file "$PROJECT_DIR/stop-all-fastapi.sh" "#!/bin/bash
set -e

SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"
cd \"\$SCRIPT_DIR\"

# Determine which docker compose command to use
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker compose\"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker-compose\"
else
    echo \"Error: docker-compose (or 'docker compose') is not installed or not in PATH\"
    exit 1
fi

echo \"Stopping FastAPI services...\"
\$COMPOSE_CMD down

echo \"Services stopped!\"
"

# Create dockerignore
create_file "$PROJECT_DIR/.dockerignore" "# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
*.egg-info/
.dist-info/
*.egg

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Build artifacts
*.whl

# Logs
*.log
logs/

# Environment
.env

# Git
.git/
.gitignore
"

# Create README.md
create_file "$PROJECT_DIR/README.md" "# $PROJECT_NAME

FastAPI Application

## Quick Start

### Start services
\`\`\`bash
chmod +x start-all-fastapi.sh ./stop-all-fastapi.sh
./start-all-fastapi.sh
\`\`\`

### Stop services
\`\`\`bash
./stop-all-fastapi.sh
\`\`\`

## Access

- Backend: http://localhost:5050
- Health check: http://localhost:5050/healthz
- API Documentation: http://localhost:5050/docs

## Usage

### Development mode
\`\`\`bash
docker compose up --build
\`\`\`

### Production mode
\`\`\`bash
docker compose up -d
\`\`\`

## Configuration

Edit \`\.env\` file to configure:
- Database connection
- Redis connection
- Environment variables

## Project Structure

\`\`\`
$PROJECT_NAME/
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   ├── server.py
│   ├── run-server.sh
│   ├── run-server-dev.sh
│   └── log-config.yaml
├── docker-compose.yml
├── .env
├── .dockerignore
├── start-all-fastapi.sh
└── stop-all-fastapi.sh
\`\`\`
"

# Create .gitignore
create_file "$PROJECT_DIR/.gitignore" "# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
*.egg-info/
.dist-info/
*.egg

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Environment
.env

# Logs
*.log
logs/

# Build
*.whl

# Docker
.docker/
"

# Make scripts executable
chmod +x "$PROJECT_DIR/backend/run-server.sh"
chmod +x "$PROJECT_DIR/backend/run-server-dev.sh"
chmod +x "$PROJECT_DIR/start-all-fastapi.sh"
chmod +x "$PROJECT_DIR/stop-all-fastapi.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FastAPI project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-all-fastapi.sh ./stop-all-fastapi.sh"
echo "3. ./start-all-fastapi.sh"
echo "4. Open http://localhost:5050/docs"
echo ""
