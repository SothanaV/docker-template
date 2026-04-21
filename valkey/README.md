# Valkey

[Valkey](https://valkey.io/) is an open-source, high-performance key-value store (Redis-compatible fork). This setup includes **Valkey 9.0** and **Redis Insight 2.66** for a web-based GUI.

## Services

| Service | Image | Port |
|---|---|---|
| valkey | `valkey/valkey:9.0-alpine` | `6379` |
| redis-insight | `redislabs/redisinsight:2.66` | `5540` |

## Quick Start

1. Configure your password in `.env`:

```env
PASSWORD=YourSuperStrongPassword1234
VALKEY_EXTRA_FLAGS="--requirepass ${PASSWORD}"
```

2. Start the services:

```bash
docker compose up -d
```

3. Access Redis Insight at [http://localhost:5540](http://localhost:5540)

## Connecting

Connect any Redis-compatible client to `localhost:6379` using the password set in `.env`.

```bash
# CLI example
docker exec -it <valkey-container> valkey-cli -a YourSuperStrongPassword1234
```

## Data Persistence

Valkey data is persisted in a named Docker volume `valkey-data`. Redis Insight settings are stored in `insight-data`.
