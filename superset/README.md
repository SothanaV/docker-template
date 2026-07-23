# superset docker
- run 
```bash
docker compose up
```

## Note
- [docker images apache/superset:6.1.0](https://hub.docker.com/r/apache/superset/tags)

## How to public dashboard
- Login as admin
- Settings > List Roles
- delete `Public` role
- edit `Gamma` role
    - add permisson
        - can explore json on Superset
        - can dashboard on Superset
        - all database access on all_database_access
- copy `Gamma` role and rename to `Public`
    - check box `Gamma`
    - action
    - Copy Role
- test and hope sucess
