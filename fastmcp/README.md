# FastMCP

Minimal Docker Compose template for a [FastMCP](https://github.com/jlowin/fastmcp) server (uv-managed, lock-free).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- [uv](https://docs.astral.sh/uv/) (only for local, non-Docker work)

## Project Structure

```
fastmcp/
├── server/
│   ├── Dockerfile        # python:3.14-slim + uv sync
│   ├── pyproject.toml    # project metadata + dependencies
│   └── server.py
├── docker-compose.yml    # dev on port 8080
└── .env
```

## Quick Start

```bash
docker compose up --build
```

- MCP endpoint: http://localhost:8080/mcp
- Health: http://localhost:8080/healthz

Stop: `docker compose down`

## Dependencies

Dependencies live in `server/pyproject.toml` under `[project].dependencies`.

```bash
uv lock                          # optional: pin locally (uv.lock is gitignored)
uv run uvicorn server:app        # run locally without Docker
```

Inside Docker, `uv sync` installs from `pyproject.toml` directly (no lockfile required).

## Environment

```env
PROJECT_NAME=mcp
PYTHONUNBUFFERED=1
```
