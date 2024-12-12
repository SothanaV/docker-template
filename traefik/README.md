# Traefic https for docker
- edit config  `config/traefik.toml`
    ```
    # .env
    ...
    [web.auth.basic]
    users = ["<USERNAME HASH PASSWORD>"]
    ...
    ```
    - https://hostingcanada.org/htpasswd-generator/
- check config
```
docker-compose config
```
- run
```
docker compose up
```

## How to use
- docker same machine
```yml
services:
    SERVICE_NAME:
        container_name: SERVICE_NAME
        ...
        labels:
            - "traefik.frontend.rule=Host:<DOMAIN>"
            - "traefik.port=<PORT>"
            - "traefik.backend=<SERVICE_NAME>"
            - "traefik.frontend.entryPoints=http,https"
```