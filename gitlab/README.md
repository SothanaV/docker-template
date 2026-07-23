# GitLab Docker Template

A Docker-based GitLab CE deployment template with OAuth2 Generic authentication support.

## Quick Start

### 1. Configure Deployment

Edit `docker-compose.yml` to set your external URL:

```yaml
hostname: git.your-domain.com
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url 'http://git.your-domain.com/'
    nginx['listen_https'] = false
    nginx['listen_port'] = 80
```

### 2. Start the Service

```bash
docker-compose up -d
```

### 3. Get Initial Root Password

The initial root password is available at `./config/initial_root_password` after the first startup:

```bash
cat ./config/initial_root_password
```

> **WARNING:** The initial password will be automatically deleted after 24 hours. Please change it as soon as possible.

## Configuration

### Docker Compose

Key ports:
- `80` - Web interface (HTTP)
- `443` - HTTPS (optional)

Volumes:
- `./config` - GitLab configuration files
- `./logs` - GitLab logs
- `./data` - GitLab data (repositories, databases, etc.)

### OAuth2 Generic Authentication

Configure OAuth2 in `gitlab.rb`:

```ruby
gitlab_rails['omniauth_providers'] = [
  {
    name: "oauth2_generic",
    label: "Your Provider",
    app_id: "your-client-id",
    app_secret: "your-client-secret",
    args: {
      client_options: {
        site: "https://your-oauth-server.com",
        user_info_url: "/api/v1/account/me",
        authorize_url: "/o/authorize/",
        token_url: "/o/token/",
      },
      user_response_structure: {
        attributes: {
          nickname: "username",
          name: "display_name",
          email: "email",
        }
      },
      strategy_class: "OmniAuth::Strategies::OAuth2Generic"
    }
  }
]
```

## Default Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 80   | HTTP     | Web interface |
| 443  | HTTPS    | HTTPS (optional) |
| 22   | SSH      | Git over SSH (if configured) |

## Credentials & Security

### Initial Root Password
After the first startup, GitLab generates an initial root password stored at:
```
./config/initial_root_password
```

> **WARNING:** This file is automatically deleted after 24 hours. Change the root password immediately after first login.

### OAuth2 Provider Credentials
Update `gitlab.rb` with your OAuth2 provider credentials:

```ruby
app_id: "your-client-id",      # OAuth2 Client ID
app_secret: "your-client-secret",  # OAuth2 Client Secret
```

### SSH Keys
Configure SSH access by adding your public keys to GitLab:
1. Log in to GitLab web interface
2. Go to **User Settings** → **SSH Keys**
3. Add your public key (`~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub`)

## Troubleshooting

- Check logs: `docker logs gitlab`
- Reconfigure GitLab: `docker exec -it gitlab gitlab-ctl reconfigure`
- Restart: `docker-compose restart`
