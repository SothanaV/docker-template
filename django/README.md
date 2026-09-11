# Django

Minimal Docker Compose template for a Django + DRF backend (uv-managed, lock-free).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- [uv](https://docs.astral.sh/uv/) (only for local, non-Docker work)

## Project Structure

```
django/
├── backend/
│   ├── backend/          # settings, urls, wsgi/asgi, health check
│   ├── Dockerfile        # python:3.14-slim + uv sync
│   ├── manage.py
│   └── pyproject.toml    # project metadata + dependencies (no requirements.txt)
├── docker-compose.yml    # postgres + backend (dev, port 8000)
└── .env
```

## Quick Start

```bash
docker compose up --build
```

- App: http://localhost:8000
- Health: http://localhost:8000/healthz/
- Admin: http://localhost:8000/admin

Migrations run automatically on start. Exec into the container for other commands:

```bash
docker compose exec backend python manage.py startapp myapp
docker compose exec backend python manage.py createsuperuser
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

CSRF_TRUSTED_ORIGINS='http://localhost:8000'
```

## Settings

`settings.py` reads everything from the environment:

```python
SECRET_KEY = os.environ.get('DJANGO_SECRET')
DEBUG = os.environ.get('STATE', None) == "dev"

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
