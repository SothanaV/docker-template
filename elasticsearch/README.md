# Elasticsearch

A Docker Compose template for [Elasticsearch](https://www.elastic.co/elasticsearch/) 7.17.27 — a distributed search and analytics engine.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)
- At least 8GB of available RAM (memory limit is set to 8g)

## Quick Start

```bash
docker compose up -d
```

Elasticsearch runs in single-node mode with X-Pack security enabled. It is accessible internally at `http://elasticsearch:9200`.

## Services

| Service         | Image                    | Internal Port | Volume                                   |
|-----------------|--------------------------|---------------|------------------------------------------|
| `elasticsearch` | `elasticsearch:7.17.27`  | 9200          | `es_data:/usr/share/elasticsearch/data`  |

## Configuration

| Environment Variable      | Default    | Description                       |
|---------------------------|------------|-----------------------------------|
| `discovery.type`          | single-node| Standalone single-node mode       |
| `xpack.security.enabled`  | true       | Enables X-Pack security           |
| `ELASTIC_PASSWORD`        | password   | Password for the `elastic` user   |

> **Warning:** Change the default `ELASTIC_PASSWORD` before deploying to any non-local environment.

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
