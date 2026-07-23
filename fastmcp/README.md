# FastMCP

A Docker Compose template for developing and deploying a [FastMCP](https://github.com/jlowin/fastmcp) (Model Context Protocol) server.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Project Structure

```
fastmcp/
├── server/               # FastMCP server source
├── docker-compose.yml    # Development configuration
├── staging.yml           # Staging configuration (multi-worker)
├── start-fast-mcp.sh     # Helper start script
└── .env                  # Environment variables
```

## Quick Start

### Development

```bash
docker compose up --build
```

Access: http://localhost:8080

### Staging

Runs with 4 workers for production-like performance:

```bash
docker compose -f staging.yml up --build
```

Access: http://localhost:8080

## Services

| Service | Build     | Port      | Dev Command              | Staging Command           |
|---------|-----------|-----------|--------------------------|---------------------------|
| `mcp`   | `./server`| 8080:8000 | `bash run-server-dev.sh` | `bash run-server.sh 4`    |

The `./server` directory is mounted into the container for hot reload during development.

## Environment Variables

Create a `.env` file in the project root:

```env
PROJECT_NAME=myapp
```

Add any MCP server-specific variables your application needs.

## Stop

```bash
docker compose down
```
