# Debezium CDC

A sandbox for Change Data Capture (CDC) using Debezium Server with PostgreSQL, Oracle, and SQL Server as data sources and Redis as the message sink.

## Architecture

```
[PostgreSQL] ──┐
               ├──> [Debezium Server #1] ──> [Redis Streams] ──> [Python Consumer]
[Oracle DB] ───┤                                                ──> [MinIO / S3]
[SQL Server] ──┘
```

## Services

| Service | Image | Port | Purpose |
|---|---|---|---|
| `postgres` | `postgres:18.0-alpine` | 5432 | Source database (PostgreSQL) |
| `oracle` | `gvenzl/oracle-free:23.8-full` | 1521 | Source database (Oracle) |
| `mssql` | `mcr.microsoft.com/mssql/server:2022-latest` | 1433 | Source database (SQL Server) |
| `redis` | `redis:7.2-alpine` | 6379 | Message sink (Redis Streams) |
| `redis-insight` | `redislabs/redisinsight:2.66` | 5540 | Redis GUI dashboard |
| `debezium-server` | `quay.io/debezium/server:2.4` | — | CDC connector for PostgreSQL |
| `debezium-server-oracle` | `quay.io/debezium/server:2.7` | — | CDC connector for Oracle |
| `debezium-server-mssql` | `quay.io/debezium/server:2.7` | — | CDC connector for SQL Server |
| `minio` | `quay.io/minio/minio` | 9000, 9001 | S3-compatible object storage |

## Configuration

Edit `.env` for database credentials, ports, and Debezium settings.

### PostgreSQL

```env
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=secret
POSTGRES_DB=sourcedb
DEBEZIUM_POSTGRES_TOPIC_PREFIX=cdc
DEBEZIUM_POSTGRES_SCHEMA_INCLUDE_LIST=public
```

### Oracle

```env
ORACLE_PORT=1521
ORACLE_PASSWORD=password
ORACLE_APP_USER=c##appuser
ORACLE_APP_PASSWORD=apppassword
DEBEZIUM_ORACLE_USER=c##dbzuser
DEBEZIUM_ORACLE_PASSWORD=dbzpassword
DEBEZIUM_ORACLE_TOPIC_PREFIX=cdc-oracle
DEBEZIUM_ORACLE_SCHEMA_INCLUDE_LIST=C##APPUSER
```

### SQL Server

```env
MSSQL_PORT=1433
MSSQL_SA_PASSWORD=YourStrong!Passw0rd
MSSQL_SA_USER=sa
MSSQL_DB=sourcedb
MSSQL_ENCRYPT=False
DEBEZIUM_MSSQL_TOPIC_PREFIX=cdc-mssql
```

### Python Consumer

```env
PYTHON_CONSUMER_STREAM_KEY=cdc.public.users
```

## Quick Start

### 1. Start all services

```bash
docker compose up -d
```

### 2. Verify services

```bash
docker compose ps
```

### 3. Explore CDC events

```bash
redis-cli
> XREAD STREAMS cdc.public.<table_name> COUNT 10 $
> XREAD STREAMS cdc-oracle.<schema>.<table_name> COUNT 10 $
> XREAD STREAMS cdc-mssql.<schema>.<table_name> COUNT 10 $
```

Or use **Redis Insight** at http://localhost:5540

### 4. (Optional) Python consumer

```bash
docker compose up -d python-consumer
```

## Initialization

### Oracle Setup

Oracle auto-initializes via scripts in `oracle-init/`:

- `01-enable-archivelog.sh` — Enables ARCHIVELOG mode and supplemental log data
- `02-setup-logminer.sql` — Creates Debezium user, application user, and sample table

### SQL Server Setup

Run the initialization script after SQL Server is ready:

```bash
# Ensure SQL Server is running
docker compose up -d mssql

# Run initialization (requires pymssql)
pip install pymssql
python mssql-init/init-db.py
```

This creates the database, `customers` table, and enables CDC.

## Stream Key Formats

- **PostgreSQL:** `cdc.<schema>.<table>` (e.g. `cdc.public.users`)
- **Oracle:** `cdc-oracle.<schema>.<table>` (e.g. `cdc-oracle.c##appuser.customers`)
- **SQL Server:** `cdc-mssql.<schema>.<table>` (e.g. `cdc-mssql.dbo.customers`)

## Stop & Cleanup

```bash
# Stop all services
docker compose down

# Stop and remove volumes (erases CDC offsets and schema history)
docker compose down -v
```
