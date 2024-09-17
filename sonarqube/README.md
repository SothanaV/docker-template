# SonarQube
- start sonarqube
```bash
docker compose up
```
- open browser <a href="http://localhost:9000">http://localhost:9000</a>
    - login
        - user: admin
        - pass : admin
    - change password

- create project
- create key
- run scanner [how to run scanner]('./scanner/README.md')

## Note
if deploy log like this
```
Elasticsearch died while starting up, with exit code 78
```

run 
```bash
sudo sysctl -w vm.max_map_count=262144
```