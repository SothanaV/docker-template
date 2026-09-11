#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# Django Project Scaffolding Script
# ============================================================

if [ -z "$1" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-django-app"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Django project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

# ============================================================
# Interactive Feature Menu
# ============================================================
echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Django Project Features${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

SELECT_DATABASE="postgresql"
SELECT_CACHE="redis"
SELECT_AUTH="default"
SELECT_TASKS="celery"
SELECT_CORS="yes"

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

echo -e "\n${YELLOW}Select message queue / caching:${NC}"
echo "  1) Redis (default)"
echo "  2) None"
read -p "  Enter choice [1]: " cache_choice
cache_choice="${cache_choice:-1}"
case $cache_choice in
    1) SELECT_CACHE="redis" ;;
    2) SELECT_CACHE="none" ;;
esac

echo -e "\n${YELLOW}Authentication:${NC}"
echo "  1) Django default auth (default)"
echo "  2) JWT (djangorestframework-simplejwt)"
echo "  3) Token auth"
read -p "  Enter choice [1]: " auth_choice
auth_choice="${auth_choice:-1}"
case $auth_choice in
    1) SELECT_AUTH="default" ;;
    2) SELECT_AUTH="jwt" ;;
    3) SELECT_AUTH="token" ;;
esac

echo -e "\n${YELLOW}Background tasks:${NC}"
echo "  1) Celery + Redis (default)"
echo "  2) None"
read -p "  Enter choice [1]: " tasks_choice
tasks_choice="${tasks_choice:-1}"
case $tasks_choice in
    1) SELECT_TASKS="celery" ;;
    2) SELECT_TASKS="none" ;;
esac

echo -e "\n${YELLOW}CORS support:${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -p "  Enter choice [1]: " cors_choice
cors_choice="${cors_choice:-1}"

# ============================================================
# Helper Functions
# ============================================================
create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

# ============================================================
# Create .env
# ============================================================
create_file "$PROJECT_DIR/.env" \
"PROJECT_NAME='$PROJECT_NAME'
PYTHONUNBUFFERED=1

# Database
DB_ENGINE='django.db.backends.postgresql'
DB_NAME='${PROJECT_NAME}_db'
DB_USER='${PROJECT_NAME}_user'
DB_PASSWORD='${PROJECT_NAME}_password'
DB_HOST=db
DB_PORT=5432

# Redis
REDIS_URL=redis://redis:6379/0

# JWT Settings (if selected)
# JWT_SECRET_KEY=change-me-generate-secret
# JWT_ACCESS_TOKEN_LIFETIME_HOURS=1
# JWT_REFRESH_TOKEN_LIFETIME_DAYS=7

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:8080
"

# ============================================================
# Create docker-compose.yml
# ============================================================
create_file "$PROJECT_DIR/docker-compose.yml" "services:
    db:
        container_name: \${PROJECT_NAME}-db
        image: postgres:16-alpine
        volumes:
            - postgres_data:/var/lib/postgresql/data
        env_file:
            - .env
        environment:
            POSTGRES_DB: \${DB_NAME}
            POSTGRES_USER: \${DB_USER}
            POSTGRES_PASSWORD: \${DB_PASSWORD}
        ports:
            - \"5432:5432\"
        healthcheck:
            test: [\"CMD-SHELL\", \"pg_isready -U \${DB_USER} -d \${DB_NAME}\"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 30s
        restart: unless-stopped

    redis:
        container_name: \${PROJECT_NAME}-redis
        image: redis:7-alpine
        ports:
            - \"6379:6379\"
        volumes:
            - redis_data:/data
        healthcheck:
            test: [\"CMD\", \"redis-cli\", \"ping\"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 10s
        restart: unless-stopped

    backend:
        container_name: \${PROJECT_NAME}-backend
        build: ./backend
        command: >
            sh -c \"python manage.py migrate &&
                   gunicorn config.wsgi:application --bind 0.0.0.0:5000 --workers 4\"
        volumes:
            - ./backend:/backend
        ports:
            - \"5050:5000\"
        env_file:
            - .env
        depends_on:
            db:
                condition: service_healthy
            redis:
                condition: service_healthy
        healthcheck:
            test: [\"CMD-SHELL\", \"curl -f http://localhost:5000/healthz || exit 1\"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 40s
        restart: unless-stopped
"

# Add celery worker if selected
if [ "$SELECT_TASKS" = "celery" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'CELERY_EOF'

    celery-worker:
        container_name: ${PROJECT_NAME}-celery
        build: ./backend
        command: celery -A config worker --loglevel=info
        volumes:
            - ./backend:/backend
        env_file:
            - .env
        depends_on:
            db:
                condition: service_healthy
            redis:
                condition: service_healthy
        restart: unless-stopped

    celery-beat:
        container_name: ${PROJECT_NAME}-celery-beat
        build: ./backend
        command: celery -A config beat --loglevel=info
        volumes:
            - ./backend:/backend
        env_file:
            - .env
        depends_on:
            db:
                condition: service_healthy
            redis:
                condition: service_healthy
        restart: unless-stopped
CELERY_EOF
fi

# ============================================================
# Create backend/Dockerfile
# ============================================================
create_file "$PROJECT_DIR/backend/Dockerfile" "FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc-dev libpq-dev libmariadb-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /backend
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
"

# ============================================================
# Create backend/config/__init__.py
# ============================================================
create_file "$PROJECT_DIR/backend/config/__init__.py" ""

# ============================================================
# Create backend/config/settings.py
# ============================================================
create_file "$PROJECT_DIR/backend/config/settings.py" "import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent

SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-change-me-in-production')
DEBUG = os.environ.get('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
]

# CORS
if os.environ.get('CORS_ENABLED', 'True') == 'True':
    INSTALLED_APPS.append('corsheaders')

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
]

if os.environ.get('CORS_ENABLED', 'True') == 'True':
    MIDDLEWARE.insert(1, 'corsheaders.middleware.CorsMiddleware')

MIDDLEWARE.extend([
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
])

ROOT_URLCONF = 'config.urls'
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]
WSGI_APPLICATION = 'config.wsgi.application'

# Database
DB_ENGINE = os.environ.get('DB_ENGINE', 'django.db.backends.postgresql')
if DB_ENGINE == 'django.db.backends.mysql':
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.mysql',
            'NAME': os.environ.get('DB_NAME', 'app'),
            'USER': os.environ.get('DB_USER', 'root'),
            'PASSWORD': os.environ.get('DB_PASSWORD', ''),
            'HOST': os.environ.get('DB_HOST', 'localhost'),
            'PORT': os.environ.get('DB_PORT', '3306'),
        }
    }
elif DB_ENGINE == 'django.db.backends.sqlite3':
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.environ.get('DB_NAME', 'app'),
            'USER': os.environ.get('DB_USER', 'appuser'),
            'PASSWORD': os.environ.get('DB_PASSWORD', 'password'),
            'HOST': os.environ.get('DB_HOST', 'db'),
            'PORT': os.environ.get('DB_PORT', '5432'),
        }
    }

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True
STATIC_URL = 'static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [],
    'DEFAULT_PERMISSION_CLASSES': [],
}

# JWT
if os.environ.get('AUTH_TYPE', 'default') == 'jwt':
    INSTALLED_APPS.append('rest_framework_simplejwt')
    from datetime import timedelta
    REST_FRAMEWORK['DEFAULT_AUTHENTICATION_CLASSES'] = [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ]

# Redis / Cache
if os.environ.get('REDIS_URL'):
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.redis.RedisCache',
            'LOCATION': os.environ.get('REDIS_URL'),
        }
    }

# Celery
if os.environ.get('REDIS_URL'):
    CELERY_BROKER_URL = os.environ.get('REDIS_URL')
    CELERY_RESULT_BACKEND = os.environ.get('REDIS_URL')
    CELERY_ACCEPT_CONTENT = ['json']
    CELERY_TASK_SERIALIZER = 'json'
    CELERY_RESULT_SERIALIZER = 'json'
"

# ============================================================
# Create backend/config/wsgi.py
# ============================================================
create_file "$PROJECT_DIR/backend/config/wsgi.py" "import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
application = get_wsgi_application()
"

# ============================================================
# Create backend/config/urls.py
# ============================================================
create_file "$PROJECT_DIR/backend/config/urls.py" "from django.contrib import admin
from django.urls import path, include
from django.views.generic import TemplateResponse

urlpatterns = [
    path('admin/', admin.site.urls),
    path('healthz', lambda r: TemplateResponse(r, {'status': 'ok'}), name='healthz'),
    path('api/', include('apps.core.urls')),
]

# JWT Auth URLs
try:
    from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
    urlpatterns.extend([
        path('api/auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
        path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    ])
except ImportError:
    pass
"

# ============================================================
# Create backend/apps/core/__init__.py
# ============================================================
create_file "$PROJECT_DIR/backend/apps/core/__init__.py" ""

# ============================================================
# Create backend/apps/core/urls.py
# ============================================================
create_file "$PROJECT_DIR/backend/apps/core/urls.py" "from django.urls import path
from . import views

urlpatterns = [
    path('hello/', views.hello, name='hello'),
    path('healthz', views.healthz, name='healthz'),
]
"

# ============================================================
# Create backend/apps/core/views.py
# ============================================================
data_check_sql = """            try:
                from django.db import connection
                cursor = connection.cursor()
                cursor.execute('SELECT 1')
                status['database'] = 'connected'
            except Exception as e:
                status['database'] = f'error: {str(e)}'"""

data_check_mysql = """            try:
                from django.db import connection
                cursor = connection.cursor()
                cursor.execute('SELECT 1')
                status['database'] = 'connected'
            except Exception as e:
                status['database'] = f'error: {str(e)}'"""

data_check_sqlite = """            status['database'] = 'sqlite'"""

if SELECT_DATABASE == "postgresql":
    data_check = data_check_sql
elif SELECT_DATABASE == "mysql":
    data_check = data_check_mysql
else:
    data_check = data_check_sqlite

create_file "$PROJECT_DIR/backend/apps/core/views.py", f"""import os
from django.http import JsonResponse, HttpResponse

def hello(request):
    return JsonResponse({{'message': 'Home', 'project': os.environ.get('PROJECT_NAME', 'Django')}})

from django.http import JsonResponse
from django.db import connection

def healthz(request):
    status = {{'status': 'ok', 'service': 'django'}}
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        status['database'] = 'connected'
    except Exception as e:
        status['database'] = f'error: {{str(e)}}'
        status['status'] = 'degraded'
    return JsonResponse(status)
"""

# ============================================================
# Create backend/apps/core/apps.py
# ============================================================
create_file "$PROJECT_DIR/backend/apps/core/apps.py" "from django.apps import AppConfig

class CoreConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.core'
"

# Add core to INSTALLED_APPS in settings
# We'll patch it later

# ============================================================
# Create manage.py
# ============================================================
create_file "$PROJECT_DIR/backend/manage.py" "#!/usr/bin/env python
import os
import sys

def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            'Couldn't import Django. Are you sure it installed?'
        ) from exc
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
"

# ============================================================
# Create requirements.txt
# ============================================================
base_packages = """django==5.0.1
djangorestframework==3.15.1
gunicorn==21.2.0
python-dotenv==1.0.1
"""

if SELECT_AUTH == "jwt":
    base_packages += "djangorestframework-simplejwt==5.3.1\n"

if SELECT_CACHE != "none":
    base_packages += "redis==5.0.4\ncelery==5.3.6\n"

if SELECT_DATABASE == "postgresql":
    base_packages += "psycopg2-binary==2.9.9\n"
elif SELECT_DATABASE == "mysql":
    base_packages += "mysqlclient==2.2.1\n"

if SELECT_CACHE != "none" and SELECT_CORS == "yes":
    base_packages += "django-cors-headers==4.3.1\n"

if SELECT_CORS == "yes":
    base_packages += "django-cors-headers==4.3.1\n"

create_file "$PROJECT_DIR/backend/requirements.txt", base_packages

# ============================================================
# Create .dockerignore
# ============================================================
create_file "$PROJECT_DIR/.dockerignore" """__pycache__/
*.py[cod]
*$py.class
*.so
.env
.venv/
venv/
.env

.vscode/
.idea/
*.swp

.DS_Store

*.log
logs/

.git/
"""

# ============================================================
# Create .gitignore
# ============================================================
create_file "$PROJECT_DIR/.gitignore" """__pycache__/
*.py[cod]
.env
venv/
.venv/
*.egg-info/
*.egg

.vscode/
.idea/

.DS_Store

*.log

db.sqlite3
"""

# ============================================================
# Create start/stop scripts
# ============================================================
create_file "$PROJECT_DIR/start-django.sh" "#!/bin/bash
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

echo \"Starting Django services...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mServices started!\"
echo -e \"Backend: \033[1;33mhttp://localhost:5050\033[0m\"
echo -e \"Admin:   \033[1;33mhttp://localhost:5050/admin\033[0m\"
echo -e \"API docs:\033[1;33m http://localhost:5050/api/\033[0m\"
echo -e \"View logs: \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:      \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-django.sh" "#!/bin/bash
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

echo \"Stopping Django services...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

# ============================================================
# Create README.md
# ============================================================
create_file "$PROJECT_DIR/README.md" "# ${PROJECT_NAME}

Django Application

## Quick Start

\`\`\`bash
chmod +x start-django.sh stop-django.sh
./start-django.sh
\`\`\`

## Access

- Backend: http://localhost:5050
- Admin: http://localhost:5050/admin
- Health check: http://localhost:5050/healthz

## Configuration

Edit \`\.env\` file.

## Project Structure

\`\`\`
${PROJECT_NAME}/
├── backend/
│   ├── config/          # Django settings, urls
│   ├── apps/
│   │   └── core/        # Core app
│   ├── Dockerfile
│   ├── manage.py
│   └── requirements.txt
├── docker-compose.yml
├── .env
├── start-django.sh
└── stop-django.sh
\`\`\`

## Commands

- **Start:** \`./start-django.sh\`
- **Stop:** \`./stop-django.sh\`
- **Migrate:** \`docker compose exec backend python manage.py migrate\`
- **Create superuser:** \`docker compose exec backend python manage.py createsuperuser\`
"

# ============================================================
# Make scripts executable
# ============================================================
chmod +x "$PROJECT_DIR/backend/manage.py"
chmod +x "$PROJECT_DIR/start-django.sh"
chmod +x "$PROJECT_DIR/stop-django.sh"

# ============================================================
# Final Output
# ============================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Django project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Features selected:"
echo -e "  Database:          ${YELLOW}$SELECT_DATABASE${NC}"
echo -e "  Cache/Redis:       ${YELLOW}$SELECT_CACHE${NC}"
echo -e "  Auth:              ${YELLOW}$SELECT_AUTH${NC}"
echo -e "  Celery:            ${YELLOW}$SELECT_TASKS${NC}"
echo -e "  CORS:              ${YELLOW}selected${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. chmod +x start-django.sh stop-django.sh"
echo "3. ./start-django.sh"
echo "4. Open http://localhost:5050/admin"
echo ""
