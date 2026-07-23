# Meilisearch

A Docker Compose template for [Meilisearch](https://www.meilisearch.com/) v1.13 — a fast, open-source search engine.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

```bash
docker compose up -d
```

Access the Meilisearch dashboard: http://localhost:7700

## Services

| Service       | Image                      | Port | Volume                       |
|---------------|----------------------------|------|------------------------------|
| `meilisearch` | `getmeili/meilisearch:v1.13` | 7700 | `meilisearch:/meili_data`  |

## Environment Variables

| Variable          | Default    | Description                    |
|-------------------|------------|--------------------------------|
| `MEILI_MASTER_KEY` | `qwer1234` | Master key for authentication  |

> **Warning:** Change `MEILI_MASTER_KEY` to a strong secret key before deploying to any non-local environment.

To customize, set environment variables directly in `docker-compose.yml` or use a `.env` file.

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
