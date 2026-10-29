# Create the virtual environment and bootstrap a bare Django project with uv.
# For a full docker-compose scaffold (db, nginx, .env, run scripts) use init-django.sh

$Project = if ($args.Count -gt 0) { $args[0] } else { "backend" }

$uv = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uv) {
    Write-Error "uv not installed -> https://docs.astral.sh/uv/"
    exit 1
}

Write-Host "Creating Django project: $Project"

uv venv .venv

if (-not (Test-Path pyproject.toml)) {
@"
[project]
name = "$Project"
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
"@ | Set-Content -Path pyproject.toml
}

uv sync
uv run django-admin startproject $Project .

New-Item -ItemType Directory -Force -Path "$Project\static" | Out-Null
Set-Content -Path "$Project\static\test.txt" -Value "test"

Write-Host ""
Write-Host "Done. Copy docker-compose.yml, staging.yml, config/, .env and run-server*.sh from the template to run it in Docker."
