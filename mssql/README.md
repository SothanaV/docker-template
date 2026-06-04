# SQL Server

A Docker Compose template for [Microsoft SQL Server](https://www.microsoft.com/en-us/sql-server) 2022 on Linux.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

```bash
docker compose up -d
```

## Services

| Service | Image                                      | Port | Volume       |
|---------|--------------------------------------------|------|--------------|
| `mssql` | `mcr.microsoft.com/mssql/server:2022-latest` | 1433 | `mssql_data` |

## Credentials

| Variable      | Default                 |
|---------------|-------------------------|
| `SA_PASSWORD` | `YourStrong!Passw0rd`   |

> **Warning:** Change the default `SA_PASSWORD` before deploying to any non-local environment. The password must meet SQL Server complexity requirements (min 8 chars, uppercase, lowercase, digit, special character).

## Connecting

**Connection string:**

```text
mssql://sa:YourStrong%21Passw0rd@localhost:1433
```

**Python (SQLAlchemy + pymssql):**

```python
from urllib.parse import quote_plus
con = f'mssql+pymssql://sa:{quote_plus("YourStrong!Passw0rd")}@localhost:1433'
```

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
