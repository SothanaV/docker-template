# Open WebUI Pipeline

A Docker Compose template for [Open WebUI Pipelines](https://github.com/open-webui/pipelines) — a custom pipeline server that extends Open WebUI with additional AI processing capabilities.

Typically used alongside the [open-webui](../open-webui/) template.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Create a `.env` file with your configuration.

2. Add your pipeline files to `./pipeline/pipelines/`.

3. Start the service:

```bash
docker compose up --build
```

Access: http://localhost:9099

## Services

| Service     | Build        | Port | Volume                         |
|-------------|--------------|------|--------------------------------|
| `pipelines` | `./pipeline` | 9099 | `./pipeline/pipelines:/app/pipelines` |

## Project Structure

```
open-webui-pipeline/
├── pipeline/
│   └── pipelines/    # Place your pipeline files here
├── docker-compose.yml
└── .env
```

## Connecting to Open WebUI

In Open WebUI settings, add the pipeline server URL:

```
http://pipelines:9099
```

(or `http://localhost:9099` if running outside Docker)

## Stop

```bash
docker compose down
```
