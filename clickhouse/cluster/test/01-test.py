import clickhouse_connect

ck = clickhouse_connect.create_client(dsn="clickhouse://admin:SuperSecretPassword123!@localhost:8123/default")

print(f"{'='*10} CLUSTER INFO {'='*10}")

print(ck.query_df("""
SELECT DISTINCT cluster 
FROM system.clusters
"""))

print(f"{'='*10} SHARD INFO {'='*10}")
print(ck.query_df("""
SELECT 
    cluster,
    shard_num,
    replica_num,
    host_name,
    port,
    is_local
FROM system.clusters
WHERE cluster = 'my_cluster'
ORDER BY shard_num, replica_num
"""))

print(f"{'='*10} Test Routing{'='*10}")
for i in range(10):
    print(f"request {i} | response from => ", end='')
    print(ck.command("""
        SELECT hostname()
"""))