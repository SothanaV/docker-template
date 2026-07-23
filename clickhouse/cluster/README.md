# ClickHouse Cluster

A three-node ClickHouse cluster with replication, coordinated by ZooKeeper and fronted by an HAProxy load balancer.

## Architecture

```
Client
  │
  ▼
HAProxy (8123 / 9000)
  ├──► clickhouse-01
  ├──► clickhouse-02
  └──► clickhouse-03
           │
           ▼
       zookeeper
```

| Service | Role |
|---------|------|
| `zookeeper` | Distributed coordination for replication |
| `clickhouse-01` | ClickHouse server — shard 1, replica 1 |
| `clickhouse-02` | ClickHouse server — shard 1, replica 2 |
| `clickhouse-03` | ClickHouse server — shard 1, replica 3 |
| `haproxy` | Round-robin load balancer with health checks |

## Ports

| Port | Service | Description |
|------|---------|-------------|
| `8123` | HAProxy | ClickHouse HTTP interface (load balanced) |
| `9000` | HAProxy | ClickHouse native protocol (load balanced) |
| `8404` | HAProxy | Stats dashboard |
| `18123` | clickhouse-01 | Direct HTTP access (debug) |
| `18124` | clickhouse-02 | Direct HTTP access (debug) |
| `18125` | clickhouse-03 | Direct HTTP access (debug) |
| `19000` | clickhouse-01 | Direct native access (debug) |
| `19001` | clickhouse-02 | Direct native access (debug) |
| `19002` | clickhouse-03 | Direct native access (debug) |
| `2181` | zookeeper | ZooKeeper client port |

## Getting Started

**Start the cluster:**
```bash
docker compose up -d
```

**Check all services are running:**
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
config.d/
├── cluster.xml       # Cluster topology and ZooKeeper address (shared by all nodes)
├── macros_1.xml      # Shard/replica macros for clickhouse-01
├── macros_2.xml      # Shard/replica macros for clickhouse-02
└── macros_3.xml      # Shard/replica macros for clickhouse-03

haproxy/
└── haproxy.cfg       # Load balancer frontends/backends
```

### Cluster

All three nodes belong to cluster `my_cluster` with a single shard and three replicas. `internal_replication=true` means inserts go to one replica and ClickHouse replicates to the others via ZooKeeper automatically.

Each node has a unique `{replica}` macro and a shared `{shard}` macro (`1`), resolved at table creation time.

### ZooKeeper

Single-node ZooKeeper instance for coordination. For production, run a 3-node ZooKeeper ensemble for fault tolerance.

| Setting | Value |
|---------|-------|
| Client port | `2181` |

## Credentials

Set in `.env`:

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

The `{shard}` and `{replica}` macros are substituted per-node from each node's `macros_*.xml`.

## Tests

Install dependencies:

```bash
pip install -r test/requirements.txt
```

| Script | Description |
|--------|-------------|
| `test/01-test.py` | Prints cluster info, shard layout, and verifies HAProxy routes across all nodes |
| `test/02-test-create-and-query,py` | Creates `orders` table on cluster, inserts 100 rows of mock data, queries per-node counts and sales summary |

```bash
python test/01-test.py
python "test/02-test-create-and-query,py"
```

## Stopping

```bash
docker compose down        # keep data
docker compose down -v     # remove all volumes (destroys data)
```
