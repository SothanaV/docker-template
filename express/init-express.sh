#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-express-app"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Express project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Express Project Features${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select framework:${NC}"
echo "  1) Vanilla Express (default)"
echo "  2) Express + TypeScript"
read -p "  Enter choice [1]: " fw_choice
fw_choice="${fw_choice:-1}"
case $fw_choice in
    1) SELECT_TS="no" ;;
    2) SELECT_TS="yes" ;;
esac

echo -e "\n${YELLOW}Select database:${NC}"
echo "  1) PostgreSQL (default)"
echo "  2) MongoDB"
echo "  3) MySQL"
echo "  4) None"
read -p "  Enter choice [1]: " db_choice
db_choice="${db_choice:-1}"
case $db_choice in
    1) SELECT_DB="postgresql" ;;
    2) SELECT_DB="mongodb" ;;
    3) SELECT_DB="mysql" ;;
    4) SELECT_DB="none" ;;
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
PORT=5000
NODE_ENV=development

# Database (if selected)
# PostgreSQL
PG_HOST=db
PG_PORT=5432
PG_USER=${PROJECT_NAME}_user
PG_PASSWORD=${PROJECT_NAME}_password
PG_DATABASE=${PROJECT_NAME}_db
# MONGODB_URI=mongodb://db:27017/${PROJECT_NAME}
# MYSQL_URI=mysql://${PROJECT_NAME}_user:${PROJECT_NAME}_password@db:3306/${PROJECT_NAME}_db
"

# Build docker-compose
dockerfile_content="services:
    backend:
        container_name: \${PROJECT_NAME}-backend
        build: ./backend
        command: npm run dev
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

if [ "$SELECT_DB" != "none" ]; then
    if [ "$SELECT_DB" = "postgresql" ]; then
        dockerfile_content+=$'
    db:
        container_name: ${PROJECT_NAME}-db
        image: postgres:16-alpine
        volumes:
            - postgres_data:/var/lib/postgresql/data
        environment:
            POSTGRES_DB: ${DB_NAME:-${PROJECT_NAME}_db}
            POSTGRES_USER: ${DB_USER:-${PROJECT_NAME}_user}
            POSTGRES_PASSWORD: ${DB_PASSWORD:-${PROJECT_NAME}_password}
        healthcheck:
            test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 30s
        restart: unless-stopped

volumes:
    postgres_data:
'
    elif [ "$SELECT_DB" = "mysql" ]; then
        dockerfile_content+=$'
    db:
        container_name: ${PROJECT_NAME}-db
        image: mysql:8.0
        volumes:
            - mysql_data:/var/lib/mysql
        environment:
            MYSQL_DATABASE: ${PROJECT_NAME}_db
            MYSQL_USER: ${PROJECT_NAME}_user
            MYSQL_PASSWORD: ${PROJECT_NAME}_password
            MYSQL_ROOT_PASSWORD: root
        healthcheck:
            test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
            interval: 10s
            timeout: 5s
            retries: 5
        restart: unless-stopped

volumes:
    mysql_data:
'
    elif [ "$SELECT_DB" = "mongodb" ]; then
        dockerfile_content+=$'
    db:
        container_name: ${PROJECT_NAME}-db
        image: mongo:7.0
        volumes:
            - mongo_data:/data/db
        environment:
            MONGO_INITDB_DATABASE: ${PROJECT_NAME}
        restart: unless-stopped

volumes:
    mongo_data:
'
    fi
fi

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

if [ "$SELECT_TS" = "yes" ]; then
    create_file "$PROJECT_DIR/backend/Dockerfile" "FROM node:20-alpine

RUN apk add --no-cache curl
WORKDIR /backend
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
CMD [\"npm\", \"run\", \"dev\"]
"

    create_file "$PROJECT_DIR/backend/package.json" "{
  \"name\": \"$PROJECT_NAME\",
  \"version\": \"1.0.0\",
  \"description\": \"$PROJECT_NAME API\",
  \"main\": \"src/index.ts\",
  \"scripts\": {
    \"dev\": \"ts-node-dev --respawn src/index.ts\",
    \"build\": \"tsc\",
    \"start\": \"node dist/index.js\",
    \"lint\": \"eslint src --ext .ts\"
  },
  \"dependencies\": {
    \"express\": \"^4.18.2\"
  },
  \"devDependencies\": {
    \"typescript\": \"^5.3.3\",
    \"ts-node-dev\": \"^2.0.0\",
    \"@types/express\": \"^4.17.21\"
  }
}
"
    create_file "$PROJECT_DIR/backend/tsconfig.json" "{
  \"compilerOptions\": {
    \"target\": \"ES2020\",
    \"module\": \"commonjs\",
    \"lib\": [\"ES2020\"],
    \"outDir\": \"./dist\",
    \"rootDir\": \"./src\",
    \"strict\": true,
    \"esModuleInterop\": true,
    \"skipLibCheck\": true,
    \"forceConsistentCasingInFileNames\": true
  },
  \"include\": [\"src/**/*\"],
  \"exclude\": [\"node_modules\"]
}
"

    create_file "$PROJECT_DIR/backend/src/index.ts" "import express, { Request, Response } from 'express';
import { env } from './config';

const app = express();
app.use(express.json());

app.get('/healthz', (_req: Request, res: Response) => {
  res.json({ status: 'ok', service: 'express' });
});

app.get('/', (_req: Request, res: Response) => {
  res.json({ message: 'Hello from Express!', project: process.env.PROJECT_NAME });
});

app.listen(env.PORT, () => {
  console.log(\$'Server running on port \$' + env.PORT);
});
"

    create_file "$PROJECT_DIR/backend/src/config/index.ts" "export const env = {
  PORT: parseInt(process.env.PORT || '5000', 10),
  HOST: process.env.HOST || '0.0.0.0',
  NODE_ENV: process.env.NODE_ENV || 'development',
};
"
else
    create_file "$PROJECT_DIR/backend/Dockerfile" "FROM node:20-alpine

RUN apk add --no-cache curl
WORKDIR /backend
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
CMD [\"npm\", \"run\", \"dev\"]
"

    create_file "$PROJECT_DIR/backend/package.json" "{
  \"name\": \"$PROJECT_NAME\",
  \"version\": \"1.0.0\",
  \"description\": \"$PROJECT_NAME API\",
  \"main\": \"src/index.js\",
  \"scripts\": {
    \"dev\": \"nodemon src/index.js\",
    \"start\": \"node src/index.js\",
    \"lint\": \"eslint src --ext .js\"
  },
  \"dependencies\": {
    \"express\": \"^4.18.2\"
  },
  \"devDependencies\": {
    \"nodemon\": \"^3.0.2\"
  }
}
"

    create_file "$PROJECT_DIR/backend/src/index.js" "const express = require('express');

const app = express();
app.use(express.json());

app.get('/healthz', (req, res) => {
  res.json({ status: 'ok', service: 'express' });
});

app.get('/', (req, res) => {
  res.json({ message: 'Hello from Express!', project: process.env.PROJECT_NAME });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(\`Server running on port \${PORT}\`);
});
"
fi

create_file "$PROJECT_DIR/.dockerignore" "node_modules/
npm-debug.log*
dist/
.env
.DS_Store

.vscode/
.idea/
"

create_file "$PROJECT_DIR/.gitignore" "node_modules/
npm-debug.log*
dist/
.env
.DS_Store
*.log
"

create_file "$PROJECT_DIR/start-express.sh" "#!/bin/bash
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

echo \"Starting Express services...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mServices started!\"
echo -e \"Backend: \033[1;33mhttp://localhost:5050\033[0m\"
echo -e \"Health:  \033[1;33mhttp://localhost:5050/healthz\033[0m\"
echo -e \"Logs:    \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:    \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-express.sh" "#!/bin/bash
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

echo \"Stopping Express services...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-express.sh"
chmod +x "$PROJECT_DIR/stop-express.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Express project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Features selected:"
echo -e "  TypeScript:  ${YELLOW}$SELECT_TS${NC}"
echo -e "  Database:    ${YELLOW}$SELECT_DB${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-express.sh stop-express.sh"
echo "3. ./start-express.sh"
echo "4. Open http://localhost:5050/"
echo ""
