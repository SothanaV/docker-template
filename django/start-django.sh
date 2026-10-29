#!/usr/bin/env bash
# Bootstrap a bare Django project (uv-managed) in the current directory.
# For a full docker-compose scaffold (db, nginx, .env, run scripts) use init-django.sh
set -euo pipefail

PROJECT="${1:-backend}"

if ! command -v uv > /dev/null 2>&1; then
    echo "Error: uv not installed -> https://docs.astral.sh/uv/"
    exit 1
fi

echo "Creating Django project: $PROJECT"

uv venv .venv

if [ ! -f pyproject.toml ]; then
    cat > pyproject.toml << EOF
[project]
name = "$PROJECT"
version = "0.1.0"
description = "Django backend"
requires-python = ">=3.14"
dependencies = [
    "django>=5.2,<6",
    "djangorestframework>=3.16,<4",
    "django-cors-headers>=4.9,<5",
    "drf-yasg>=1.21.11,<2",
    "gunicorn>=23,<24",
    "psycopg2-binary>=2.9.10,<3",
]

[tool.uv]
package = false
EOF
fi

uv sync
uv run django-admin startproject "$PROJECT" .

mkdir -p "$PROJECT/static"
echo "test" > "$PROJECT/static/test.txt"

echo ""
echo "Done. Copy docker-compose.yml, staging.yml, config/, .env and run-server*.sh from the template to run it in Docker."
