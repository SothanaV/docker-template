# ClickHouse Cluster

A two-node ClickHouse cluster with replication, coordinated by ClickHouse Keeper and fronted by an HAProxy load balancer.

## Architecture

```
Client
  │
  ▼
HAProxy (8123 / 9000)
  ├──► clickhouse-node1 ─┐
  └──► clickhouse-node2 ─┤
                         ▼
                 clickhouse-keeper
```

| Service | Role |
|---------|------|
| `clickhouse-keeper` | Distributed coordination (ZooKeeper replacement) |
| `clickhouse-node1` | ClickHouse server — shard 1, replica node1 |
| `clickhouse-node2` | ClickHouse server — shard 1, replica node2 |
| `haproxy` | Round-robin load balancer with health checks |

## Ports

| Port | Description |
|------|-------------|
| `8123` | ClickHouse HTTP interface (load balanced) |
| `9000` | ClickHouse native protocol (load balanced) |
| `8404` | HAProxy stats dashboard |

## Getting Started

**Start the cluster:**
```bash
docker compose up -d
```

**Check all services are healthy:**
```bash
docker compose ps
```

**Verify the cluster is up:**
```bash
curl http://localhost:8123/ping
# Ok.
```

## Configuration

```
config/
├── keeper/
│   └── keeper_config.xml          # Keeper server, Raft, and storage settings
├── haproxy/
│   └── haproxy.cfg                # Load balancer frontends/backends
├── node1/
│   ├── config.d/
│   │   └── cluster.xml            # Cluster topology, Keeper address, macros (replica=node1)
│   └── users.d/
│       └── default-user.xml       # Removes default user, creates admin user
└── node2/
    ├── config.d/
    │   └── cluster.xml            # Same topology, different macro (replica=node2)
    └── users.d/
        └── default-user.xml       # Same user config as node1
```

### Cluster

Both nodes belong to cluster `my_cluster` with a single shard and two replicas. `internal_replication=true` means inserts go to one replica and ClickHouse replicates to the other automatically via Keeper.

Each node has a unique `{replica}` macro (`node1` / `node2`) and a shared `{shard}` macro (`1`), used when creating replicated tables.

### Keeper

Single-node Keeper instance for coordination. For production, run at least 3 Keeper nodes for fault tolerance.

| Setting | Value |
|---------|-------|
| Client port | `9181` |
| Raft port | `9234` |
| Operation timeout | `10,000 ms` |
| Session timeout | `30,000 ms` |

## Credentials

Configured in `.env` and applied via `users.d/default-user.xml` on both nodes. The `default` user is removed and replaced with `admin`.

```env
CLICKHOUSE_USER=admin
CLICKHOUSE_PASSWORD=SuperSecretPassword123!
CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
```

> Change the password before deploying to any non-local environment.

## Connecting

**Native protocol (clickhouse-client):**
```bash
clickhouse-client --host localhost --port 9000 --user admin --password SuperSecretPassword123!
```

**HTTP:**
```bash
curl -u admin:SuperSecretPassword123! 'http://localhost:8123/?query=SELECT+version()'
```

**HAProxy stats:**
```
http://localhost:8404/stats
```

## Creating a Replicated Table

```sql
CREATE TABLE events ON CLUSTER my_cluster
(
    id       UInt64,
    ts       DateTime,
    payload  String
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/events', '{replica}')
ORDER BY (ts, id);
```

The `{shard}` and `{replica}` macros are substituted per-node from `cluster.xml`.

## Volumes

| Volume | Contents |
|--------|---------|
| `keeper_data` | Keeper coordination log and snapshots |
| `ch_node1_data` | Node 1 table data |
| `ch_node2_data` | Node 2 table data |

## Stopping

```bash
docker compose down        # keep volumes
docker compose down -v     # remove volumes (destroys all data)
```
