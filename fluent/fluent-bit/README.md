# Fluent Bit

A Docker Compose template for [Fluent Bit](https://fluentbit.io/) 1.8 — a lightweight log forwarder and processor.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)
- A running Elasticsearch instance (default target)

## Quick Start

1. Edit `./conf/fluent-bit.conf` to configure your log inputs, filters, and outputs.

2. Start the service:

```bash
docker compose up -d
```

## Services

| Service     | Image                    | Port  | Config                        |
|-------------|--------------------------|-------|-------------------------------|
| `fluent-bit`| `fluent/fluent-bit:1.8`  | 18000 | `./conf/:/etc/fluent-bit/:ro` |

## Environment Variables

| Variable      | Default         | Description                   |
|---------------|-----------------|-------------------------------|
| `FLB_ES_HOST` | `elasticsearch` | Elasticsearch host             |
| `FLB_ES_PORT` | `9200`          | Elasticsearch port             |

Set these in the `docker-compose.yml` or a `.env` file to point to your Elasticsearch instance.

## Configuration

Place your Fluent Bit configuration files in the `./conf/` directory. The main config file must be named `fluent-bit.conf`.

Example minimal config forwarding to Elasticsearch:

```ini
[SERVICE]
    Flush     5
    Log_Level info

[INPUT]
    Name  forward
    Listen 0.0.0.0
    Port  18000

[OUTPUT]
    Name  es
    Match *
    Host  ${FLB_ES_HOST}
    Port  ${FLB_ES_PORT}
    Index fluent-bit
```

## Stop

```bash
docker compose down
```
