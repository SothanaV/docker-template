# Flask

Minimal Docker Compose template for a Flask backend (uv-managed, lock-free).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- [uv](https://docs.astral.sh/uv/) (only for local, non-Docker work)

## Project Structure

```
flask/
├── backend/
│   ├── Dockerfile        # python:3.14-slim + uv sync
│   ├── pyproject.toml    # project metadata + dependencies
│   └── server.py
├── docker-compose.yml    # dev on port 5050
└── .env
```

## Quick Start

```bash
docker compose up --build
```

- App: http://localhost:5050
- Health: http://localhost:5050/healthz

Stop: `docker compose down`

## Dependencies

Dependencies live in `backend/pyproject.toml` under `[project].dependencies`.

```bash
uv lock                        # optional: pin locally (uv.lock is gitignored)
uv run gunicorn server:app     # run locally without Docker
```

Inside Docker, `uv sync` installs from `pyproject.toml` directly (no lockfile required).

## Environment

```env
PROJECT_NAME=myapp
```
