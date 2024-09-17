# SonarQube Scanner
- create key from sonarqube
- edit `sonar-project.properties`
```
sonar.host.url=http://sonarqube:9000
sonar.login=
```
- edit `docker-compose.yml`
```yml
 scanner:
    volumes:
      - ../../django/backend:/usr/src/backend # map to your project dir
```
- run scanner
```
docker compose up
```