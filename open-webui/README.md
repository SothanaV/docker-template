# Open WebUI

A Docker Compose template for [Open WebUI](https://openwebui.com/) v0.8.12 — a web interface for interacting with LLMs — backed by PostgreSQL and Qdrant.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Create a `.env` file with your configuration (see below).

2. Start the services:

```bash
docker compose up -d
```

Access: http://localhost:8080

## Services

| Service      | Image                              | Port              | Volume         |
|--------------|------------------------------------|-------------------|----------------|
| `db`         | `postgres:18-alpine`               | —                 | `db`           |
| `qdrant`     | `qdrant/qdrant:latest`             | 6333, 6334        | `qdrant_data`  |
| `open-webui` | `ghcr.io/open-webui/open-webui:0.8.12` | 8080         | `open-webui`   |

## Environment Variables

Create a `.env` file:

```env
PROJECT_NAME=myapp

# PostgreSQL
POSTGRES_DB=openwebui
POSTGRES_USER=openwebui
POSTGRES_PASSWORD=openwebui_password

# Open WebUI
DATABASE_URL=postgresql://openwebui:openwebui_password@db:5432/openwebui

# Qdrant (optional)
QDRANT_URI=http://qdrant:6333
```

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
