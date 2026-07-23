# Code Server

A Docker Compose template for [code-server](https://github.com/coder/code-server) 4.104.1 — VS Code running in the browser.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

```bash
docker compose up --build
```

Access: <http://localhost:8080>

## Services

| Service  | Build | Port | Volume                        |
|----------|-------|------|-------------------------------|
| `vscode` | `.`   | 8080 | `.config:/home/coder/.config` |

## Notes

- The image is based on `codercom/code-server:4.104.1` with common dev tools pre-installed (`git`, `wget`, `curl`, `gcc`, `g++`, `docker-compose`).
- Your code-server settings and extensions are persisted in the `.config` directory.
- To set a password, add the `PASSWORD` environment variable in `docker-compose.yml` or a `.env` file.

## Stop

```bash
docker compose down
```
