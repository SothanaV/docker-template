# Express

A Docker Compose template for developing and deploying an [Express.js](https://expressjs.com/) backend service.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Run the setup script to scaffold the project:

```bash
sh start-express.sh
```

1. Start the service:

```bash
docker compose up --build
```

Access: <http://localhost:3000>

## Project Structure

```text
express/
├── backend/             # Express application source
├── docker-compose.yml   # Docker Compose configuration
└── .env                 # Environment variables
```

Files created by `start-express.sh` inside `backend/`:

- `Dockerfile`
- `runserver.sh`
- `.dockerignore`

## Services

| Service   | Build       | Port | Command              |
|-----------|-------------|------|----------------------|
| `backend` | `./backend` | 3000 | `bash runserver.sh`  |

## Environment Variables

Create a `.env` file:

```env
PROJECT_NAME=myapp
```

## Stop

```bash
docker compose down
```
