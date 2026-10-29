# Django

Minimal Docker Compose template for a Django + DRF backend (uv-managed, lock-free).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- [uv](https://docs.astral.sh/uv/) (only for local, non-Docker work)
- `bash` + `openssl` (only the scaffold scripts, they use bash arrays and generate secrets)

## Project Structure

```
django/
├── backend/
│   ├── backend/          # settings, urls, wsgi/asgi, health.py, docs.py
│   ├── static/           # optional static sources (STATICFILES_DIRS)
│   ├── Dockerfile        # python:3.14-slim + uv sync
│   ├── manage.py
│   ├── pyproject.toml    # project metadata + dependencies (no requirements.txt)
│   ├── run-server-dev.sh # dev:  runserver 0.0.0.0:8000
│   └── run-server.sh     # prod: collectstatic + gunicorn N workers
├── config/nginx.conf     # nginx vhost for staging.yml (proxy + static + media)
├── docker-compose.yml    # postgres + backend (dev, port 8000)
├── staging.yml           # postgres + gunicorn + nginx (media/static volumes)
├── init-django.sh        # scaffold a whole project, interactive menu
├── start-django.sh       # scaffold a bare django project with uv (linux/macos)
├── start-django.ps1      # same as above, PowerShell
└── .env
```

## Quick Start

```bash
docker compose up --build
```

- App: http://localhost:8000
- Health: http://localhost:8000/healthz/
- Admin: http://localhost:8000/admin
- Swagger: http://localhost:8000/swagger/
- ReDoc: http://localhost:8000/redoc/

Migrations run automatically on start. Exec into the container for other commands:

```bash
docker compose exec backend python manage.py startapp myapp
docker compose exec backend python manage.py createsuperuser
```

## Scaffold a New Project

`init-django.sh` builds a complete, runnable project (compose + staging + nginx + `.env` + scripts) and asks for the parts you want: database (postgres/mysql/sqlite), redis cache, auth (default/JWT/token), celery, CORS, api docs.

```bash
cd ~/wherever
bash django/init-django.sh my_project   # name must be a valid python module name
cd my_project && ./start-django.sh
```

For a bare project without Docker files (`pyproject.toml` + `django-admin startproject`):

```bash
mkdir my_project && cd my_project
bash start-django.sh          # or: .\start-django.ps1 on Windows
```

## Dependencies

Dependencies live in `backend/pyproject.toml` under `[project].dependencies`.

```bash
uv lock                        # optional: pin locally (uv.lock is gitignored)
uv run python manage.py ...    # run locally without Docker
```

Inside Docker, `uv sync` installs from `pyproject.toml` directly (no lockfile required).

## Environment ```.env```

```bash
PROJECT_NAME=<projectname>
STATE=dev                     # "dev" enables DEBUG

DJANGO_SECRET=<secret key>
DJANGO_ALLOW_ASYNC_UNSAFE=true
PYTHONUNBUFFERED=1

POSTGRES_DB=<db name>
POSTGRES_USER=<db user>
POSTGRES_PASSWORD=<db password>
POSTGRES_HOST=${PROJECT_NAME}-db
POSTGRES_PORT=5432
PGDATA=/var/lib/postgresql/data

DJANGO_ALLOWED_HOSTS='*'
CSRF_TRUSTED_ORIGINS='http://localhost:8000'
CORS_ALLOW_ALL_ORIGINS=true

IS_BEHIND_PROXY=false
FORCE_SCRIPT_NAME='/'
# REDIS_URL=redis://redis:6379/0    # needs a redis service in docker-compose.yml
```

## Settings

`settings.py` reads everything from the environment:

```python
SECRET_KEY = os.environ.get('DJANGO_SECRET')
DEBUG = os.environ.get('STATE', None) == "dev"
ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', '*').split(',')

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('POSTGRES_DB'),
        'USER': os.environ.get('POSTGRES_USER'),
        'PASSWORD': os.environ.get('POSTGRES_PASSWORD'),
        'HOST': os.environ.get('POSTGRES_HOST'),
        'PORT': os.environ.get('POSTGRES_PORT'),
    }
}
```

Installed apps: `corsheaders`, `rest_framework`, `drf_yasg`.

## Static and Media (server-side render)

```python
STATIC_URL = '/static/'
STATIC_ROOT = os.environ.get('STATIC_ROOT', BASE_DIR / 'staticfiles')   # collectstatic target
STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')]
MEDIA_URL = '/media/'
MEDIA_ROOT = os.environ.get('MEDIA_ROOT', BASE_DIR / 'media')
```

`urls.py` already serves media in development:

```python
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```

## CORS and CSRF

```python
CORS_ALLOW_ALL_ORIGINS = os.environ.get('CORS_ALLOW_ALL_ORIGINS', 'True').lower() == 'true'
CSRF_TRUSTED_ORIGINS = [o for o in os.environ.get('CSRF_TRUSTED_ORIGINS', 'http://localhost:8000').split(',') if o]

SESSION_COOKIE_NAME = os.environ.get('PROJECT_NAME', 'django')
SESSION_COOKIE_AGE = 60 * 60 * 24       # sec
SESSION_EXPIRE_AT_BROWSER_CLOSE = True
```

## Api docs (drf-yasg)

Already wired: `drf_yasg` in `INSTALLED_APPS`, routes in `backend/backend/docs.py`.

Starting from a bare project instead:

```bash
uv add drf-yasg
```

```python
INSTALLED_APPS = [..., 'drf_yasg']
```

and add the `schema_view` + `urlpatterns_docs` block from `backend/backend/docs.py` to your urls.

- `/swagger/` Swagger UI, `/redoc/` ReDoc, `/swagger.json` and `/swagger.yaml` the schema

## DRF authentication

Default is session + basic auth. For JWT:

```bash
uv add djangorestframework-simplejwt
```

```python
INSTALLED_APPS = [..., 'rest_framework_simplejwt']

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework.authentication.BasicAuthentication',
    ],
}

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
```

## Behind a proxy / subpath

```python
IS_BEHIND_PROXY = os.environ.get('IS_BEHIND_PROXY', 'False').lower() == 'true'

if IS_BEHIND_PROXY:
    FORCE_SCRIPT_NAME = os.environ.get('FORCE_SCRIPT_NAME', '/system')
    STATIC_URL = f'{FORCE_SCRIPT_NAME}/static/'
    MEDIA_URL = f'{FORCE_SCRIPT_NAME}/media/'
    USE_X_FORWARDED_HOST = True
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
else:
    FORCE_SCRIPT_NAME = None
```

## Staging / Production

`staging.yml` runs gunicorn behind nginx and shares the collected static and uploaded media through volumes:

```bash
# .env: STATE=production
docker compose -f staging.yml up --build -d
```

| service | what it does |
| ------- | ------------ |
| `db` | postgres:18-alpine, named volume `db` |
| `backend` | `sh run-server.sh 4` → collectstatic + gunicorn (4 workers) |
| `nginx` | port 8000, `config/nginx.conf`, serves `/static/` and `/media/` |

The compose file sets `STATIC_ROOT=/var/www/static/` and `MEDIA_ROOT=/var/www/media/`, the same paths nginx reads, so `settings.py` does not need editing per environment.

## Health check

`/healthz/` reports database and cache; returns `503` when degraded.

```json
{"status": "healthy", "service": "django", "postgresql": "connected", "redis": "connected"}
```

The cache check follows `CACHES`: without `REDIS_URL` Django uses local memory, so the redis field is reported from that backend. Set `REDIS_URL` and add a redis service to get a real connection check.
