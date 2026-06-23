# Open WebUI

A Docker Compose template for [Open WebUI](https://openwebui.com/) v0.8.12 — a web interface for interacting with LLMs — backed by PostgreSQL, Qdrant (vector DB), and an optional Redis for HA/multi-instance deployment.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Setups

This template includes 2 deployment options:

1. **Normal** — Single instance with Qdrant vector DB
2. **HA (High Availability)** — Multiple instances behind Nginx load balancer with Redis for session/WebSocket sharing

## Quick Start — Normal

1. Create a `.env` file with your configuration (see below).
2. Start the services:

```bash
docker compose up -d
```

Access: http://localhost:8080

### Normal Services

| Service      | Image                                      | Port                    | Volume         |
|--------------|--------------------------------------------|-------------------------|----------------|
| `db`         | `postgres:18-alpine`                       | —                       | `db`           |
| `qdrant`     | `qdrant/qdrant:latest`                     | 6333 (REST), 6334 (gRPC)| `qdrant_data`  |
| `open-webui` | `ghcr.io/open-webui/open-webui:0.8.12`     | 8080                    | `open-webui`   |

## Quick Start — HA

1. Set `WEBUI_SECRET_KEY`, `REDIS_URL`, and `WEBSOCKET_MANAGER=redis` in `.env` (see below).
2. Start the services:

```bash
docker compose -f docker-compose.yml -f docker-ha.yaml up -d
```

Access: http://localhost:8080 (via Nginx load balancer)

### HA Services

| Service          | Image                                | Port              | Volume                    |
|------------------|--------------------------------------|-------------------|---------------------------|
| `db`             | `postgres:18-alpine`                 | —                 | `db`                      |
| `redis`          | `redis:7.2-alpine`                   | —                 | `redis_db`                |
| `redis-insight`  | `redislabs/redisinsight:3.6`         | 5540              | `redisinsight_data`       |
| `open-webui-1`   | `ghcr.io/open-webui/open-webui:0.8.12`| —                | —                         |
| `open-webui-2`   | `ghcr.io/open-webui/open-webui:0.8.12`| —                | —                         |
| `nginx`          | `nginx:1.25.2-alpine`                | 8080              | `nginx.conf`              |

## Environment Variables

### Required Variables

```env
PROJECT_NAME=myapp                    # Project identifier, used for container names
POSTGRES_DB=openwebui                 # Database name
POSTGRES_USER=openwebui               # Database user
POSTGRES_PASSWORD=your_password       # Database password
```

### Database & Vector Store

```env
POSTGRES_HOST=${PROJECT_NAME}-db
POSTGRES_PORT=5432
PGDATA=/var/lib/postgresql/data

DATABASE_URL=postgresql://openwebui:your_password@db:5432/openwebui
QDRANT_URI=http://qdrant:6333
QDRANT_API_KEY=your_api_key           # Optional: Protect Qdrant REST API
VECTOR_DB=qdrant
```

### Qdrant Configuration

```env
QDRANT__SERVICE__API_KEY=your_api_key
QDRANT__LOG_LEVEL=INFO                # DEBUG, INFO, WARN, ERROR
```

### Open WebUI — Ollama

```env
OLLAMA_BASE_URL=http://ollama:11434    # Leave empty if not using Ollama
```

### Open WebUI — Authentication (OIDC/OAuth)

```env
OPENID_PROVIDER_URL=                  # OIDC well-known URL
ENABLE_SIGNUP=false
ENABLE_OAUTH_SIGNUP=true              # Allow OAuth users to automatically sign up
ENABLE_LOGIN_FORM=false               # Disable username/password login
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
OAUTH_PROVIDER_NAME=dsm               # Display name for OAuth provider
OAUTH_CLIENT_ID=
OAUTH_CLIENT_SECRET=
OAUTH_SCOPES=openid email profile
OAUTH_USERNAME_CLAIM=username

# Group ↔ Role synchronization
OAUTH_GROUP_CLAIM=roles               # Claim that contains group/role info
OAUTH_GROUP_DEFAULT_SHARE=members      # Default group to assign roles to
ENABLE_OAUTH_GROUP_MANAGEMENT=true
DEFAULT_USER_ROLE=user
```

### HA / Multi-Instance (Optional)

Required for `docker-ha.yaml` deployment:

```env
WEBUI_SECRET_KEY=your_secret_key      # Shared secret for sessions between instances
REDIS_URL=redis://redis:6379/0         # Redis connection URL
WEBSOCKET_REDIS_URL=redis://redis:6379/0
WEBSOCKET_MANAGER=redis                # Use Redis for WebSocket pub/sub
UVICORN_WORKERS=8                      # Number of Uvicorn workers
```

## Stop

### Normal

```bash
docker compose down
```

### HA

```bash
docker compose -f docker-compose.yml -f docker-ha.yaml down
```

To remove all data in either setup, append `-v` to the command.
