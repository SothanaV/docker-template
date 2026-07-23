# Qdrant

A Docker Compose template for [Qdrant](https://qdrant.tech/) — a high-performance vector database for AI/ML applications.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

```bash
docker compose up -d
```

Access:
- REST API: http://localhost:6333
- Web UI: http://localhost:6333/dashboard
- gRPC: `localhost:6334`

## Services

| Service  | Image              | Ports              | Volume                        |
|----------|--------------------|--------------------|-------------------------------|
| `qdrant` | `qdrant/qdrant:latest` | 6333 (REST), 6334 (gRPC) | `qdrant_data:/qdrant/storage` |

## Environment Variables

Create a `.env` file for any Qdrant configuration:

```env
QDRANT__SERVICE__API_KEY=your_api_key
```

See the [Qdrant configuration docs](https://qdrant.tech/documentation/guides/configuration/) for all available options.

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
