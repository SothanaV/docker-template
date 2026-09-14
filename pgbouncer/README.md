# PgBouncer

A Docker Compose template for [PgBouncer](https://www.pgbouncer.org/) connection
pooling in front of two PostgreSQL databases.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Start the stack:

```bash
docker compose up -d
```

2. Create the auth role and lookup function on the backend DB (one-time setup,
   required for `auth_query`):

```sql
CREATE USER pgbouncer_auth WITH PASSWORD 'super_secret_auth_pw';

CREATE OR REPLACE FUNCTION user_lookup(in_user text, out uname text, out phash text)
RETURNS record AS $$
    SELECT usename, passwd FROM pg_shadow WHERE usename = in_user;
$$ LANGUAGE sql SECURITY DEFINER;

REVOKE ALL ON FUNCTION user_lookup(text) FROM public;
GRANT EXECUTE ON FUNCTION user_lookup(text) TO pgbouncer_auth;
```

3. Connect through the pooler using the alias (`db1` / `db2`) as the database name:

```
postgresql://user:password@localhost:6432/db1
postgresql://user2:password@localhost:6432/db2
```

## Services

| Service     | Image                                     | Port | Volume                    |
|-------------|-------------------------------------------|------|---------------------------|
| `db1`       | `postgres:18.0-alpine`                    | 15432 | `db1:/var/lib/postgresql/data` |
| `db2`       | `postgres:18.0-alpine`                    | 25432 | `db2:/var/lib/postgresql/data` |
| `pgbouncer` | `ghcr.io/cloudnative-pg/pgbouncer:latest` | 6432  | -                         |

## Files

| File            | Purpose                                                        |
|-----------------|----------------------------------------------------------------|
| `pgbouncer.ini` | Database aliases, auth, and pooling configuration             |
| `userlist.txt`  | Credentials for the `pgbouncer_auth` lookup user              |
| `.env`          | `PROJECT_NAME` used for container naming                      |

## Pooling Configuration

Defined in `pgbouncer.ini`:

```ini
pool_mode         = transaction
max_client_conn   = 1000
default_pool_size = 20
```

## Stop

```bash
docker compose down
```

To remove all data:

```bash
docker compose down -v
```
