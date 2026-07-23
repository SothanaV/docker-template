# Flowise

A Docker Compose template for [FlowiseAI](https://flowiseai.com/) v2.2.7 — a visual workflow builder for LLM applications and AI pipelines.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Create a `.env` file with your database credentials (see below).

2. Start the services:

```bash
docker compose up -d
```

Access: http://localhost:3000

## Services

| Service  | Image                        | Port | Volume           |
|----------|------------------------------|------|------------------|
| `db`     | `postgres:17.3-alpine`       | —    | `postgres_data`  |
| `redis`  | `redis:7.4-alpine`           | 6379 | `redis_data`     |
| `flowise`| `flowiseai/flowise:2.2.7`    | 3000 | `flowise_data`   |

## Environment Variables

Create a `.env` file:

```env
# PostgreSQL
POSTGRES_DB=flowise
POSTGRES_USER=flowise
POSTGRES_PASSWORD=flowise_password

# Flowise
DATABASE_TYPE=postgres
DATABASE_HOST=db
DATABASE_PORT=5432
DATABASE_NAME=flowise
DATABASE_USER=flowise
DATABASE_PASSWORD=flowise_password
```

See the [FlowiseAI environment variables docs](https://docs.flowiseai.com/configuration/environment-variables) for all available options.

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
