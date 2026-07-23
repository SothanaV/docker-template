# Promptail (Nginx + Promtail)

A Docker Compose template that combines Nginx with [Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/) to ship Nginx access logs to [Loki](https://grafana.com/oss/loki/).

Pairs with the [grafana-loki](../grafana-loki/) template for a full log observability stack.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)
- A running Loki instance (configure the push URL in `./config/promtail/promtail.yaml`)

## Quick Start

1. Edit `./config/promtail/promtail.yaml` to set your Loki push URL:

```yaml
clients:
  - url: http://<loki-host>:3100/loki/api/v1/push
```

2. Edit `./config/nginx/nginx.conf` as needed for your reverse proxy setup.

3. Start the services:

```bash
docker compose up -d
```

## Services

| Service    | Image                     | Ports       | Config                               |
|------------|---------------------------|-------------|--------------------------------------|
| `nginx`    | `nginx:1.25.2`            | 8000, 8080  | `./config/nginx/nginx.conf`          |
| `promtail` | `grafana/promtail:2.5.0`  | —           | `./config/promtail/promtail.yaml`    |

## Project Structure

```
promptail/
├── config/
│   ├── nginx/
│   │   └── nginx.conf         # Nginx server configuration
│   └── promtail/
│       └── promtail.yaml      # Promtail configuration
└── docker-compose.yml
```

## How It Works

Nginx writes access logs to the shared `log` volume. Promtail tails that volume and forwards the log entries to Loki using the push API.

## Stop

```bash
docker compose down
```

To remove all log data:

```bash
docker compose down -v
```
