# ClickHouse Standalone

A Docker Compose template for a single-node [ClickHouse](https://clickhouse.com/) instance — a fast open-source column-oriented database.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Create a `.env` file with your credentials (see below).

1. Start ClickHouse:

```bash
docker compose up -d
```

Access the HTTP interface: <http://localhost:8123>

## Services

| Service      | Image                                          | Port | Volume            |
|--------------|------------------------------------------------|------|-------------------|
| `clickhouse` | `bitnamilegacy/clickhouse:25.6.2-debian-12-r0` | 8123 | `clickhouse-data` |

## Environment Variables

Create a `.env` file:

```env
PROJECT_NAME=myapp
CLICKHOUSE_USER=admin
CLICKHOUSE_PASSWORD=SuperSecretPassword123!
CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
```

> **Warning:** Change the default password before deploying to any non-local environment.

## Overriding Configuration

Edit `config/override.xml` to customize ClickHouse settings.

### Log Level

Set `<level>` under `<logger>` to one of:

```xml
<logger>
    <level>information</level>
</logger>
```

Available levels: `trace`, `debug`, `information`, `warning`, `error`, `fatal`, `none`

## Connecting

**HTTP:**

```bash
curl -u admin:SuperSecretPassword123! 'http://localhost:8123/?query=SELECT+version()'
```

**clickhouse-client:**

```bash
clickhouse-client --host localhost --port 9000 --user admin --password SuperSecretPassword123!
```

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
