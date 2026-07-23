# MinIO

A Docker Compose template for [MinIO](https://min.io/) — a high-performance, S3-compatible object storage service.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

```bash
docker compose up -d
```

Access the MinIO console: <http://localhost:9001>

Default credentials:

- User: `minio`
- Password: `minio123`

> **Warning:** Change the default credentials before deploying to any non-local environment.

## Services

| Service | Image                                            | Ports             | Volume |
|---------|--------------------------------------------------|-------------------|--------|
| `minio` | `quay.io/minio/minio:RELEASE.2025-07-23T15-54-02Z` | 9000 (API), 9001 (Console) | `data` |

## Connecting

**S3-compatible API endpoint:** `http://localhost:9000`

**AWS CLI example:**

```bash
aws --endpoint-url http://localhost:9000 s3 ls
```

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
