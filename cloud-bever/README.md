# CloudBeaver

A Docker Compose template for [CloudBeaver](https://hub.docker.com/r/dbeaver/cloudbeaver) — a web-based database management tool.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

```bash
docker compose up -d
```

Access: http://localhost:8978

On first launch, CloudBeaver will guide you through the initial server configuration.

## Services

| Service       | Image                        | Port | Volume                          |
|---------------|------------------------------|------|---------------------------------|
| `cloudbeaver` | `dbeaver/cloudbeaver:latest` | 8978 | `cloudbeaver:/opt/cloudbeaver/workspace` |

## Environment Variables

Create a `.env` file and set the project name:

```env
PROJECT_NAME=myapp
```

For automatic server configuration, see the [CloudBeaver configuration docs](https://github.com/dbeaver/cloudbeaver/wiki/Server-configuration#automatic-server-configuration).

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
