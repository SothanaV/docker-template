# MySQL

A Docker Compose template for [MySQL](https://www.mysql.com/) 8.0.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Create a `.env` file with your database credentials (see below).

2. Start MySQL:

```bash
docker compose up -d
```

## Services

| Service | Image       | Port | Volume                    |
|---------|-------------|------|---------------------------|
| `mysql` | `mysql:8.0` | 3306 | `db:/var/lib/mysql`       |

## Environment Variables

Create a `.env` file in the project root:

```env
PROJECT_NAME=myapp
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_DATABASE=mydb
MYSQL_USER=myuser
MYSQL_PASSWORD=mypassword
```

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
