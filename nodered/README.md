# Node-RED

A Docker Compose template for [Node-RED](https://nodered.org/) — a low-code, flow-based programming tool for wiring together hardware devices, APIs, and online services.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

```bash
docker compose up -d
```

Access: <http://localhost:1880>

## Services

| Service    | Image                     | Port | Volume          |
|------------|---------------------------|------|-----------------|
| `node-red` | `nodered/node-red:latest` | 1880 | `node-red-data` |

## Configuration

- **Timezone**: Edit `TZ` in [docker-compose.yml](docker-compose.yml) — defaults to `UTC`, e.g. `Asia/Bangkok`.
- **Data Persistence**: Flows, credentials, and installed nodes are stored in the named Docker volume `node-red-data` (mounted at `/data`).

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
