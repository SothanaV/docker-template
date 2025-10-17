# Image registry
- create password
```
mkdir -p auth
# firsttime
htpasswd -Bbn youruser yourpass > auth/htpasswd

# other
htpasswd -Bbn youruser yourpass >> auth/htpasswd
```

- edit config `config.yml`
```yml

registry:
  hostname: registry:5000
  insecure: true
  username: admin
  password: qwer1234
```

- start registry and UI
```
docker compose up
```