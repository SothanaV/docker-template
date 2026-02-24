# Gitlab runner docker
1. start gitlab runner
```
docker compose up -d
```
2. setup register
- go to gitlab > project > settings > ci/cd > runner > create runner > copy token
- run register runner
```
docker compose exec -it gitlab-runner gitlab-runner register
```
- following instruction

3. edit file config.toml
add
```
[[runners]]
...
  [runners.docker]
  ...
  volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache", "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"]
  ...
```

4. restart gitlab runner
```
docker compose restart gitlab-runner
```