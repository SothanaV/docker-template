# CKAN

A Docker Compose template for [CKAN](https://ckan.org/) — an open-source data management system, based on the [Thai GDC CKAN image](https://gitlab.nectec.or.th/opend/ckan-docker-thai-gdc).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Copy `.env.example` to `.env` and configure the required variables.

1. Start all services:

```bash
docker compose up -d
```

## Services

| Service   | Image / Build                     | Description                            |
|-----------|-----------------------------------|----------------------------------------|
| `nginx`   | Custom build (`nginx/`)           | Reverse proxy, exposed on `NGINX_PORT` |
| `ckan`    | `thepaeth/ckan-thai_gdc:v3.0.2`   | CKAN application                       |
| `db-ckan` | Custom build (`postgresql/`)      | PostgreSQL with CKAN extensions        |
| `solr`    | Solr (from upstream)              | Search index for CKAN                  |
| `redis`   | Redis                             | Background job queue                   |

## Environment Variables

Key variables in `.env`:

| Variable                       | Description                               |
|--------------------------------|-------------------------------------------|
| `PROJECT_NAME`                 | Prefix for container names                |
| `NGINX_PORT`                   | Host port to expose CKAN on               |
| `DEFAULT_URL`                  | Public site URL (e.g. `http://localhost`) |
| `POSTGRES_PASSWORD`            | PostgreSQL password for the `ckan` user   |
| `DATASTORE_READONLY_PASSWORD`  | Password for the read-only datastore user |
| `TZ`                           | Timezone (e.g. `Asia/Bangkok`)            |

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
