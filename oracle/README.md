# Oracle Database

A Docker Compose template for [Oracle Database Free](https://www.oracle.com/database/free/) 23c, using the [gvenzl/oracle-free](https://github.com/gvenzl/oci-oracle-free) image.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

```bash
docker compose up -d
```

## Services

| Service  | Image                        | Port | Volume |
|----------|------------------------------|------|--------|
| `oracle` | `gvenzl/oracle-free:23-full` | 1521 | `data` |

## Configuration

| Variable                | Default                       | Description                              |
|-------------------------|-------------------------------|------------------------------------------|
| `ORACLE_RANDOM_PASSWORD` | `true`                       | Generates a random SYS/SYSTEM password   |
| `APP_USER`              | `my_user`                     | Application user to create               |
| `APP_USER_PASSWORD`     | `password_i_should_change`    | Password for the application user        |

> **Warning:** Change `APP_USER_PASSWORD` before deploying to any non-local environment.

When `ORACLE_RANDOM_PASSWORD=true`, the generated SYS/SYSTEM password is printed to the container logs on first start:

```bash
docker compose logs oracle | grep "ORACLE PASSWORD"
```

## Connecting

```text
Host:     localhost
Port:     1521
Service:  FREEPDB1
User:     my_user
Password: password_i_should_change
```

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
