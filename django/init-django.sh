#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Django Project Scaffolding Script (uv + Docker Compose)
#   ./init-django.sh <project-name>
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "${1:-}" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my_project"
    exit 1
fi

PROJECT_NAME="$1"

if ! [[ "$PROJECT_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo -e "${RED}Error: '$PROJECT_NAME' is not a valid python module name${NC}"
    echo "It becomes DJANGO_SETTINGS_MODULE, so use letters, digits and underscore only."
    exit 1
fi

PROJECT_DIR="$(pwd)/$PROJECT_NAME"

if [ -e "$PROJECT_DIR" ]; then
    echo -e "${RED}Error: $PROJECT_DIR already exists${NC}"
    exit 1
fi

echo -e "${GREEN}Creating Django project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

# ============================================================
# Interactive Feature Menu
# ============================================================
echo -e "\n${CYAN}==========================================${NC}"
echo -e "${CYAN}   Django Project Features${NC}"
echo -e "${CYAN}==========================================${NC}\n"

echo -e "${YELLOW}Select database:${NC}"
echo "  1) PostgreSQL (default)"
echo "  2) MySQL"
echo "  3) SQLite"
read -r -p "  Enter choice [1]: " db_choice
case "${db_choice:-1}" in
    2) SELECT_DATABASE="mysql" ;;
    3) SELECT_DATABASE="sqlite" ;;
    *) SELECT_DATABASE="postgresql" ;;
esac

echo -e "\n${YELLOW}Cache / message queue:${NC}"
echo "  1) Redis (default)"
echo "  2) None"
read -r -p "  Enter choice [1]: " cache_choice
case "${cache_choice:-1}" in
    2) SELECT_CACHE="none" ;;
    *) SELECT_CACHE="redis" ;;
esac

echo -e "\n${YELLOW}Authentication:${NC}"
echo "  1) Django default auth (default)"
echo "  2) JWT (djangorestframework-simplejwt)"
echo "  3) Token auth (rest_framework.authtoken)"
read -r -p "  Enter choice [1]: " auth_choice
case "${auth_choice:-1}" in
    2) SELECT_AUTH="jwt" ;;
    3) SELECT_AUTH="token" ;;
    *) SELECT_AUTH="default" ;;
esac

echo -e "\n${YELLOW}Background tasks:${NC}"
echo "  1) Celery + Redis"
echo "  2) None (default)"
read -r -p "  Enter choice [2]: " tasks_choice
case "${tasks_choice:-2}" in
    1) SELECT_TASKS="celery" ;;
    *) SELECT_TASKS="none" ;;
esac

echo -e "\n${YELLOW}CORS support:${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -r -p "  Enter choice [1]: " cors_choice
case "${cors_choice:-1}" in
    2) SELECT_CORS="no" ;;
    *) SELECT_CORS="yes" ;;
esac

echo -e "\n${YELLOW}Api docs (drf-yasg):${NC}"
echo "  1) Yes (default)"
echo "  2) No"
read -r -p "  Enter choice [1]: " docs_choice
case "${docs_choice:-1}" in
    2) SELECT_DOCS="no" ;;
    *) SELECT_DOCS="yes" ;;
esac

# Celery needs a broker
if [ "$SELECT_TASKS" = "celery" ]; then
    SELECT_CACHE="redis"
fi

if [ "$SELECT_CORS" = "yes" ]; then CORS_ENABLED=True; else CORS_ENABLED=False; fi
if [ "$SELECT_DOCS" = "yes" ]; then API_DOCS=True; else API_DOCS=False; fi

# ============================================================
# Secrets and derived values
# ============================================================
random_string() {
    openssl rand -base64 64 | tr -d '\n+/=' 
}

DB_PASSWORD="$(random_string | cut -c1-32)"
DJANGO_SECRET="$(random_string | cut -c1-50)"

DB_ENGINE="django.db.backends.postgresql"
if [ "$SELECT_DATABASE" = "mysql" ]; then DB_ENGINE="django.db.backends.mysql"; fi
if [ "$SELECT_DATABASE" = "sqlite" ]; then DB_ENGINE="django.db.backends.sqlite3"; fi

# ============================================================
# Layout
# ============================================================
mkdir -p "$PROJECT_DIR/config"
mkdir -p "$PROJECT_DIR/backend/$PROJECT_NAME"
mkdir -p "$PROJECT_DIR/backend/apps/core"
mkdir -p "$PROJECT_DIR/backend/static"
echo "test" > "$PROJECT_DIR/backend/static/test.txt"

# ============================================================
# backend/pyproject.toml
# ============================================================
deps=("django>=5.2,<6" "djangorestframework>=3.16,<4" "gunicorn>=23,<24")

case "$SELECT_DATABASE" in
    postgresql) deps+=("psycopg2-binary>=2.9.10,<3") ;;
    mysql) deps+=("mysqlclient>=2.2,<3") ;;
esac
if [ "$SELECT_CACHE" = "redis" ]; then deps+=("redis>=5,<6"); fi
if [ "$SELECT_TASKS" = "celery" ]; then deps+=("celery>=5.4,<6"); fi
if [ "$SELECT_AUTH" = "jwt" ]; then deps+=("djangorestframework-simplejwt>=5.3,<6"); fi
if [ "$SELECT_CORS" = "yes" ]; then deps+=("django-cors-headers>=4.9,<5"); fi
if [ "$SELECT_DOCS" = "yes" ]; then deps+=("drf-yasg>=1.21.11,<2"); fi

dependencies=""
for dep in "${deps[@]}"; do
    dependencies="$dependencies    \"$dep\",
"
done
dependencies="${dependencies%$'\n'}"

cat > "$PROJECT_DIR/backend/pyproject.toml" << EOF
[project]
name = "__PROJECT__"
version = "0.1.0"
description = "__PROJECT__ Django backend"
requires-python = ">=3.14"
dependencies = [
$dependencies
]

[tool.uv]
package = false
EOF

# ============================================================
# backend/Dockerfile
# ============================================================
apt_packages="git netcat-traditional curl iputils-ping"
if [ "$SELECT_DATABASE" = "mysql" ]; then
    apt_packages="$apt_packages build-essential default-libmysqlclient-dev"
fi

cat > "$PROJECT_DIR/backend/Dockerfile" << EOF
FROM python:3.14-slim

RUN apt-get update --fix-missing && \\
    apt install -y $apt_packages && \\
    apt-get clean


ENV PYTHONUNBUFFERED=1 \\
    PYTHONDONTWRITEBYTECODE=1 \\
    UV_PROJECT_ENVIRONMENT=/venv \\
    PATH="/venv/bin:\$PATH"

WORKDIR /backend

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml ./
RUN uv sync

COPY . .
EOF

# ============================================================
# backend run scripts
# ============================================================
cat > "$PROJECT_DIR/backend/run-server-dev.sh" << 'EOF'
while ! nc -w 1 -z ${POSTGRES_HOST} ${POSTGRES_PORT};
do sleep 5;
done;

uv run python manage.py runserver 0.0.0.0:8000
EOF

cat > "$PROJECT_DIR/backend/run-server.sh" << 'EOF'
while ! nc -w 1 -z ${POSTGRES_HOST} ${POSTGRES_PORT};
do sleep 5;
done;

uv run python manage.py collectstatic --no-input

n_worker=${1:-4}
echo n_worker=$n_worker
uv run gunicorn --workers=$n_worker --timeout 300 --log-level debug --bind 0.0.0.0:8000 __PROJECT__.wsgi
EOF

# ============================================================
# backend/manage.py
# ============================================================
cat > "$PROJECT_DIR/backend/manage.py" << 'EOF'
#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', '__PROJECT__.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
EOF

# ============================================================
# backend/<project-name> package
# ============================================================
cat > "$PROJECT_DIR/backend/$PROJECT_NAME/__init__.py" << 'EOF'
try:
    from .celery import app as celery_app

    __all__ = ("celery_app",)
except ImportError:
    pass
EOF

cat > "$PROJECT_DIR/backend/$PROJECT_NAME/wsgi.py" << 'EOF'
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', '__PROJECT__.settings')

application = get_wsgi_application()
EOF

cat > "$PROJECT_DIR/backend/$PROJECT_NAME/asgi.py" << 'EOF'
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', '__PROJECT__.settings')

application = get_asgi_application()
EOF

cat > "$PROJECT_DIR/backend/$PROJECT_NAME/health.py" << 'EOF'
from django.core.cache import cache
from django.db import connections
from django.http import JsonResponse
from django.urls import path


def healthz(request):
    status = {"status": "healthy", "service": "__PROJECT__"}

    # Check database
    try:
        with connections['default'].cursor() as cursor:
            cursor.execute("SELECT 1")
        status["database"] = "connected"
    except Exception as e:
        status["database"] = f"disconnected: {str(e)}"
        status["status"] = "degraded"

    # Check cache
    try:
        cache.get("_health_check_")
        status["cache"] = "connected"
    except Exception:
        status["cache"] = "disconnected"

    code = 503 if status["status"] != "healthy" else 200
    return JsonResponse(status, status=code)


urlpatterns_health = [
    path("healthz/", healthz, name="healthz"),
]
EOF

if [ "$SELECT_TASKS" = "celery" ]; then
    cat > "$PROJECT_DIR/backend/$PROJECT_NAME/celery.py" << 'EOF'
import os

from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', '__PROJECT__.settings')

app = Celery('__PROJECT__')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
EOF
fi

# ============================================================
# backend/<project-name>/settings.py
# ============================================================
cat > "$PROJECT_DIR/backend/$PROJECT_NAME/settings.py" << 'EOF'
"""Django settings for __PROJECT__ project."""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get('DJANGO_SECRET', None)
DEBUG = os.environ.get('STATE', None) == "dev"
ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', '*').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'apps.core',
]

AUTH_TYPE = os.environ.get('AUTH_TYPE', 'default')
if AUTH_TYPE == 'jwt':
    INSTALLED_APPS.append('rest_framework_simplejwt')
if AUTH_TYPE == 'token':
    INSTALLED_APPS.append('rest_framework.authtoken')
if os.environ.get('CORS_ENABLED', 'False').lower() == 'true':
    INSTALLED_APPS.append('corsheaders')
if os.environ.get('API_DOCS', 'False').lower() == 'true':
    INSTALLED_APPS.append('drf_yasg')

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

if 'corsheaders' in INSTALLED_APPS:
    MIDDLEWARE.insert(1, 'corsheaders.middleware.CorsMiddleware')

ROOT_URLCONF = '__PROJECT__.urls'

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

WSGI_APPLICATION = '__PROJECT__.wsgi.application'

# POSTGRES_* is the naming used by .env for every engine except sqlite
DB_ENGINE = os.environ.get('DB_ENGINE', 'django.db.backends.postgresql')
if DB_ENGINE == 'django.db.backends.sqlite3':
    DATABASES = {
        'default': {
            'ENGINE': DB_ENGINE,
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': DB_ENGINE,
            'NAME': os.environ.get('POSTGRES_DB', None),
            'USER': os.environ.get('POSTGRES_USER', None),
            'PASSWORD': os.environ.get('POSTGRES_PASSWORD', None),
            'HOST': os.environ.get('POSTGRES_HOST', None),
            'PORT': os.environ.get('POSTGRES_PORT', None),
        }
    }

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

STATIC_URL = '/static/'
STATIC_ROOT = os.environ.get('STATIC_ROOT', os.path.join(BASE_DIR, 'staticfiles'))
STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')]
MEDIA_URL = '/media/'
MEDIA_ROOT = os.environ.get('MEDIA_ROOT', os.path.join(BASE_DIR, 'media'))
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

SESSION_COOKIE_NAME = os.environ.get('PROJECT_NAME', '__PROJECT__')
SESSION_COOKIE_AGE = 60 * 60 * 24
SESSION_EXPIRE_AT_BROWSER_CLOSE = True

CORS_ALLOW_ALL_ORIGINS = os.environ.get('CORS_ALLOW_ALL_ORIGINS', 'True').lower() == 'true'
CSRF_TRUSTED_ORIGINS = [
    origin for origin in os.environ.get('CSRF_TRUSTED_ORIGINS', 'http://localhost:8000').split(',') if origin
]

AUTHENTICATION_CLASSES = [
    'rest_framework.authentication.SessionAuthentication',
    'rest_framework.authentication.BasicAuthentication',
]
if AUTH_TYPE == 'jwt':
    AUTHENTICATION_CLASSES.insert(0, 'rest_framework_simplejwt.authentication.JWTAuthentication')
if AUTH_TYPE == 'token':
    AUTHENTICATION_CLASSES.insert(0, 'rest_framework.authentication.TokenAuthentication')

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': AUTHENTICATION_CLASSES,
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
}

if AUTH_TYPE == 'jwt':
    from datetime import timedelta

    SIMPLE_JWT = {
        'ACCESS_TOKEN_LIFETIME': timedelta(hours=1),
        'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
        'ROTATE_REFRESH_TOKENS': False,
        'BLACKLIST_AFTER_ROTATION': True,
        'ALGORITHM': 'HS256',
        'SIGNING_KEY': SECRET_KEY,
        'AUTH_HEADER_TYPES': ('Bearer',),
        'USER_ID_FIELD': 'id',
        'USER_ID_CLAIM': 'user_id',
        'UPDATE_LAST_LOGIN': True,
    }

REDIS_URL = os.environ.get('REDIS_URL', None)
if REDIS_URL:
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.redis.RedisCache',
            'LOCATION': REDIS_URL,
        }
    }
    CELERY_BROKER_URL = REDIS_URL
    CELERY_RESULT_BACKEND = REDIS_URL
    CELERY_ACCEPT_CONTENT = ['json']
    CELERY_TASK_SERIALIZER = 'json'
    CELERY_RESULT_SERIALIZER = 'json'

IS_BEHIND_PROXY = os.environ.get('IS_BEHIND_PROXY', 'False').lower() == 'true'
if IS_BEHIND_PROXY:
    # The subpath the app is served under (xxx.yyy.com/system)
    FORCE_SCRIPT_NAME = os.environ.get('FORCE_SCRIPT_NAME', '/system')
    STATIC_URL = f'{FORCE_SCRIPT_NAME}/static/'
    MEDIA_URL = f'{FORCE_SCRIPT_NAME}/media/'
    USE_X_FORWARDED_HOST = True
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
else:
    FORCE_SCRIPT_NAME = None
EOF

# ============================================================
# backend/<project-name>/urls.py
# ============================================================
cat > "$PROJECT_DIR/backend/$PROJECT_NAME/urls.py" << 'EOF'
"""__PROJECT__ URL Configuration"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path, re_path

from .health import urlpatterns_health

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('apps.core.urls')),
    *urlpatterns_health,
]

try:
    from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

    urlpatterns += [
        path('api/auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
        path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    ]
except ImportError:
    pass

try:
    from rest_framework.authtoken.views import obtain_auth_token

    urlpatterns += [path('api/auth/token-auth/', obtain_auth_token, name='obtain_auth_token')]
except ImportError:
    pass

try:
    from drf_yasg import openapi
    from drf_yasg.views import get_schema_view
    from rest_framework import permissions

    schema_view = get_schema_view(
        openapi.Info(
            title='__PROJECT__ API',
            default_version='v1',
            description="""<br><p>__PROJECT__</p><br><br>SignIn to admin <a href="/admin/"> Admin page </a>""",
            terms_of_service="https://www.google.com/policies/terms/",
            contact=openapi.Contact(email="contact@snippets.local"),
            license=openapi.License(name="BSD License"),
        ),
        public=True,
        permission_classes=[permissions.AllowAny],
    )

    urlpatterns += [
        re_path(r'^swagger(?P<format>\.json|\.yaml)$', schema_view.without_ui(cache_timeout=0), name='schema-json'),
        re_path(r'^swagger/$', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
        re_path(r'^redoc/$', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
    ]
except ImportError:
    pass

# Serve media in development (nginx serves it in staging/production)
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
EOF

# ============================================================
# backend/apps/core
# ============================================================
: > "$PROJECT_DIR/backend/apps/__init__.py"
: > "$PROJECT_DIR/backend/apps/core/__init__.py"

cat > "$PROJECT_DIR/backend/apps/core/apps.py" << 'EOF'
from django.apps import AppConfig


class CoreConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.core'
EOF

cat > "$PROJECT_DIR/backend/apps/core/urls.py" << 'EOF'
from django.urls import path

from . import views

urlpatterns = [
    path('hello/', views.hello, name='hello'),
]
EOF

cat > "$PROJECT_DIR/backend/apps/core/views.py" << 'EOF'
import os

from django.http import JsonResponse


def hello(request):
    return JsonResponse({"message": "Hello", "project": os.environ.get('PROJECT_NAME', '__PROJECT__')})
EOF

if [ "$SELECT_TASKS" = "celery" ]; then
    cat > "$PROJECT_DIR/backend/apps/core/tasks.py" << 'EOF'
from celery import shared_task


@shared_task
def hello_task():
    return "hello from celery"
EOF
fi

# ============================================================
# docker-compose.yml (dev)
# ============================================================
{
    echo "volumes:"
    echo "    db: {}"
    if [ "$SELECT_CACHE" = "redis" ]; then
        echo "    redis_data: {}"
    fi
} > "$PROJECT_DIR/docker-compose.yml"

cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'

services:
    db:
        container_name: ${PROJECT_NAME}-db
        image: postgres:18-alpine
        volumes:
            - db:/var/lib/postgresql/data
        env_file:
            - .env
        healthcheck:
            test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 20s
EOF

if [ "$SELECT_CACHE" = "redis" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'

    redis:
        container_name: ${PROJECT_NAME}-redis
        image: redis:7-alpine
        volumes:
            - redis_data:/data
        healthcheck:
            test: ["CMD", "redis-cli", "ping"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 10s
EOF
fi

cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'

    backend:
        container_name: ${PROJECT_NAME}-backend
        build: ./backend
        command: >
            sh -c "python manage.py migrate --noinput &&
                   sh run-server-dev.sh"
        volumes:
            - ./backend:/backend
        ports:
            - 8000:8000
        env_file:
            - .env
        healthcheck:
            test: ["CMD", "python", "-c", "import urllib.request,sys; r=urllib.request.urlopen('http://localhost:8000/healthz/'); sys.exit(0 if r.status==200 else 1)"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 30s
        depends_on:
            db:
                condition: service_healthy
EOF

if [ "$SELECT_CACHE" = "redis" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'
            redis:
                condition: service_healthy
EOF
fi

if [ "$SELECT_TASKS" = "celery" ]; then
    cat >> "$PROJECT_DIR/docker-compose.yml" << 'EOF'

    celery-worker:
        container_name: ${PROJECT_NAME}-celery
        build: ./backend
        command: celery -A __PROJECT__ worker --loglevel=info
        volumes:
            - ./backend:/backend
        env_file:
            - .env
        depends_on:
            redis:
                condition: service_healthy

    celery-beat:
        container_name: ${PROJECT_NAME}-celery-beat
        build: ./backend
        command: celery -A __PROJECT__ beat --loglevel=info
        volumes:
            - ./backend:/backend
        env_file:
            - .env
        depends_on:
            redis:
                condition: service_healthy
EOF
fi

# ============================================================
# staging.yml (gunicorn + nginx) + nginx.conf
# ============================================================
cat > "$PROJECT_DIR/staging.yml" << 'EOF'
volumes:
    media: {}
    static: {}
    db: {}

services:
    db:
        container_name: ${PROJECT_NAME}-db
        image: postgres:18-alpine
        volumes:
            - db:/var/lib/postgresql/data
        env_file:
            - .env
        healthcheck:
            test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
            interval: 10s
            timeout: 5s
            retries: 5
            start_period: 20s

    backend:
        container_name: ${PROJECT_NAME}-backend
        build: ./backend
        command: sh run-server.sh 4
        volumes:
            - ./backend:/backend
            - media:/var/www/media/
            - static:/var/www/static/
        env_file:
            - .env
        environment:
            STATIC_ROOT: /var/www/static/
            MEDIA_ROOT: /var/www/media/
        depends_on:
            db:
                condition: service_healthy
        healthcheck:
            test: ["CMD", "python", "-c", "import urllib.request,sys; r=urllib.request.urlopen('http://localhost:8000/healthz/'); sys.exit(0 if r.status==200 else 1)"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 40s

    nginx:
        container_name: ${PROJECT_NAME}-nginx
        image: nginx:1.25.2-alpine
        ports:
            - 8000:8000
        volumes:
            - ./config/nginx.conf:/etc/nginx/conf.d/default.conf
            - media:/var/www/media/
            - static:/var/www/static/
        env_file:
            - .env
        depends_on:
            backend:
                condition: service_healthy
        environment:
            NGINX_ENVSUBST_TEMPLATE_SUFFIX: ".conf"
EOF

cat > "$PROJECT_DIR/config/nginx.conf" << 'EOF'
upstream backend {
    server backend:8000;
}

server {
    listen 8000;
    listen [::]:8000;

    server_name _;

    proxy_buffer_size   128k;
    proxy_buffers   4 256k;
    proxy_busy_buffers_size   256k;
    client_max_body_size 100M;

    location / {
        proxy_pass http://backend/;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static/ {
        autoindex on;
        alias /var/www/static/;
    }

    location /media/ {
        alias /var/www/media/;
    }
}
EOF

# ============================================================
# .env, ignore files, start/stop scripts, README
# ============================================================
REDIS_ENV=""
if [ "$SELECT_CACHE" = "redis" ]; then
    REDIS_ENV="
REDIS_URL=redis://redis:6379/0"
fi

cat > "$PROJECT_DIR/.env" << EOF
PROJECT_NAME='__PROJECT__'
COMPOSE_PROJECT_NAME=\${PROJECT_NAME}
STATE=dev

DJANGO_SECRET='__SECRET__'
DJANGO_ALLOW_ASYNC_UNSAFE=true
PYTHONUNBUFFERED=1

DB_ENGINE='__DB_ENGINE__'
POSTGRES_DB='__PROJECT__'
POSTGRES_USER='__PROJECT__'
POSTGRES_PASSWORD='__DB_PASSWORD__'
POSTGRES_HOST=\${PROJECT_NAME}-db
POSTGRES_PORT=5432
PGDATA=/var/lib/postgresql/data${REDIS_ENV}

AUTH_TYPE=__AUTH__
CORS_ENABLED=__CORS__
API_DOCS=__DOCS__
CORS_ALLOW_ALL_ORIGINS=true
CSRF_TRUSTED_ORIGINS='http://localhost:8000'

IS_BEHIND_PROXY=false
FORCE_SCRIPT_NAME='/'
EOF

cat > "$PROJECT_DIR/.gitignore" << 'EOF'
# python
env/
.venv/
__pycache__/
*.pyc

# uv
uv.lock

# django
*.sqlite3
staticfiles/
media/

# secrets / editors / os
.env
.vscode/
.idea/
.DS_Store
*.log
EOF

cat > "$PROJECT_DIR/backend/.dockerignore" << 'EOF'
__pycache__/
*.py[cod]
.env
.venv/
env/
uv.lock
.git/
.DS_Store
EOF

cat > "$PROJECT_DIR/start-django.sh" << 'EOF'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v docker > /dev/null 2>&1; then
    echo "Error: docker not installed"
    exit 1
fi

echo "Starting Django services..."
docker compose down --remove-orphans > /dev/null 2>&1 || true
docker compose up --build -d
echo ""
echo -e "\033[0;32mServices started!"
echo -e "App:       \033[1;33mhttp://localhost:8000"
echo -e "Admin:     \033[1;33mhttp://localhost:8000/admin"
echo -e "Health:    \033[1;33mhttp://localhost:8000/healthz/"
echo -e "View logs: \033[1;33mdocker compose logs -f"
echo -e "Stop:      \033[1;33mdocker compose down"
EOF

cat > "$PROJECT_DIR/stop-django.sh" << 'EOF'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping Django services..."
docker compose down
echo "Services stopped!"
EOF

cat > "$PROJECT_DIR/README.md" << 'EOF'
# __PROJECT__

Django backend (uv-managed, Docker Compose).

## Quick Start

```bash
./start-django.sh          # dev: python runserver
```

- App: http://localhost:8000
- Admin: http://localhost:8000/admin
- Health: http://localhost:8000/healthz/
- Api docs: http://localhost:8000/swagger/

## Staging / Production (gunicorn + nginx)

Set `STATE=production` in `.env`, then:

```bash
docker compose -f staging.yml up --build -d
```

## Commands

```bash
docker compose exec backend python manage.py startapp myapp
docker compose exec backend python manage.py createsuperuser
docker compose exec backend python manage.py migrate
```

## Dependencies

Edit `backend/pyproject.toml`, then `uv sync` locally or `docker compose build` in Docker.

## Structure

```
__PROJECT__/
├── backend/
│   ├── __PROJECT__/      # settings, urls, wsgi/asgi, health
│   ├── apps/core/        # example app
│   ├── static/
│   ├── Dockerfile
│   ├── manage.py
│   ├── pyproject.toml
│   ├── run-server-dev.sh
│   └── run-server.sh
├── config/nginx.conf
├── docker-compose.yml    # dev
├── staging.yml           # gunicorn + nginx
├── .env
├── start-django.sh
└── stop-django.sh
```
EOF

# ============================================================
# Apply placeholders
# ============================================================
find "$PROJECT_DIR" -type f \( -name '*.py' -o -name '*.toml' -o -name '*.yml' -o -name '*.sh' -o -name '*.md' -o -name 'Dockerfile' -o -name '.env' \) -print0 \
    | xargs -0 sed -i \
        -e "s/__PROJECT__/$PROJECT_NAME/g" \
        -e "s|__SECRET__|$DJANGO_SECRET|g" \
        -e "s|__DB_PASSWORD__|$DB_PASSWORD|g" \
        -e "s|__DB_ENGINE__|$DB_ENGINE|g" \
        -e "s/__AUTH__/$SELECT_AUTH/g" \
        -e "s/__CORS__/$CORS_ENABLED/g" \
        -e "s/__DOCS__/$API_DOCS/g"

chmod +x "$PROJECT_DIR/backend/manage.py" \
         "$PROJECT_DIR/backend/run-server.sh" \
         "$PROJECT_DIR/backend/run-server-dev.sh" \
         "$PROJECT_DIR/start-django.sh" \
         "$PROJECT_DIR/stop-django.sh"

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Django project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Features selected:"
echo -e "  Database:    ${YELLOW}$SELECT_DATABASE${NC}"
echo -e "  Cache:       ${YELLOW}$SELECT_CACHE${NC}"
echo -e "  Auth:        ${YELLOW}$SELECT_AUTH${NC}"
echo -e "  Tasks:       ${YELLOW}$SELECT_TASKS${NC}"
echo -e "  CORS:        ${YELLOW}$SELECT_CORS${NC}"
echo -e "  Api docs:    ${YELLOW}$SELECT_DOCS${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME"
echo "2. ./start-django.sh"
echo "3. Open http://localhost:8000/healthz/"
