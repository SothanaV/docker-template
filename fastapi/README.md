# FastAPI

A Docker Compose template for developing and deploying a FastAPI backend service.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Project Structure

```
fastapi/
├── backend/              # FastAPI application source
├── docker-compose.yml    # Development configuration (port 5050)
├── staging.yml           # Staging configuration (port 5000)
├── start-fastAPI.sh      # Helper start script
└── .env                  # Environment variables
```

## Quick Start

### Development

```bash
docker compose up --build
```

Access: http://localhost:5050

### Staging

```bash
docker compose -f staging.yml up --build
```

Access: http://localhost:5000

## Services

| Service   | Build      | Dev Port | Staging Port | Command              |
|-----------|------------|----------|--------------|----------------------|
| `backend` | `./backend`| 5050     | 5000         | `sh run-server.sh`   |

## Environment Variables

Create a `.env` file in the project root:

```env
PROJECT_NAME=myapp
```

Add any additional FastAPI-specific variables your application needs.

## Stop

```bash
docker compose down
```
