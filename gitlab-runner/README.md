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