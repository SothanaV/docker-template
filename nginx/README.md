# Nginx

A Docker Compose template for [Nginx](https://nginx.org/) 1.25.2-alpine as a reverse proxy, suitable for serving static files and proxying backend services.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Edit `./config/nginx.conf` to configure your server blocks and proxy rules.

2. Start the service:

```bash
docker compose up -d
```

Access:
- http://localhost:8000
- http://localhost:8080

## Services

| Service | Image                    | Ports       | Config                         |
|---------|--------------------------|-------------|--------------------------------|
| `nginx` | `nginx:1.25.2-alpine`    | 8000, 8080  | `./config/nginx.conf`          |

## Volumes

| Volume   | Purpose                     |
|----------|-----------------------------|
| `media`  | Uploaded media files        |
| `static` | Collected static files      |

## Environment Variables

Create a `.env` file:

```env
PROJECT_NAME=myapp
```

The `NGINX_ENVSUBST_TEMPLATE_SUFFIX: ".conf"` setting enables environment variable substitution in `.conf` template files.

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
