# Label Studio

A Docker Compose template for [Label Studio](https://labelstud.io/) — an open-source data annotation and labeling platform.

> Note: The directory name `label-stuio` is a typo for `label-studio`.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Create a `.env` file with your database and app configuration (see below).

2. Start the services:

```bash
docker compose up -d
```

Access: http://localhost:18080

## Services

| Service | Image                              | Port       | Volume                   |
|---------|------------------------------------|------------|--------------------------|
| `db`    | `postgres:17-alpine`               | —          | `db:/var/lib/postgresql/data` |
| `app`   | `heartexlabs/label-studio:20240926.221338-develop-056e48992` | 18080:8080 | `./data:/label-studio/data` |

## Environment Variables

Create a `.env` file:

```env
DJANGO_DB=default
POSTGRESQLV2_SERVICE_HOST=db
DATABASE_NAME=labelstudio
DATABASE_USER=labelstudio
DATABASE_PASSWORD=labelstudio
LABEL_STUDIO_HOST=http://localhost:18080
```

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
