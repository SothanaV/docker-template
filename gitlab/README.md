# gitlab
### deploy
- edit docker-compose.yml
```yaml
    ...
    hostname: git.services.storemesh.com
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://git.services.storemesh.com/'
        nginx['listen_https'] = false
        nginx['listen_port'] = 80
    ...
```

- password at `./config/initial_root_password`

WARNING!! => please change password, init password will delete after up 24hours
```
...
Password: jtI8ur.....
...
```