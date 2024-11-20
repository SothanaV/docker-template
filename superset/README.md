# superset docker
- run 
```bash
docker compose up
```

## Note
- [docker images amancevice/superset:4.1.0](https://hub.docker.com/r/amancevice/superset/tags)

## How to public dashboard
- Login as admin
- Settings > List Roles
- delete `Public` role
- edit `Gramma` role
    - add permisson
        - explor on superset
        - explot json on superset
- copy `Gramma` role and rename to `Public`
- test and hope sucess