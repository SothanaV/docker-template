# n8n

n8n workflow automation with PostgreSQL backend and OIDC (SSO) authentication via external hooks.

## Services

| Service    | Image                   | Port |
|------------|-------------------------|------|
| `n8n`      | `n8nio/n8n:1.123.30`   | 5678 |
| `postgres`  | `postgres:18-alpine`   | —    |

## Quick Start

```bash
# Copy and configure environment variables
cp .env .env.local

# Start services
docker-compose up -d
```

Access n8n at: `http://localhost:5678`

## Configuration

Edit [.env](.env) before starting:

### Required

| Variable | Description |
|---|---|
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `POSTGRES_NON_ROOT_PASSWORD` | Same as above |
| `OIDC_ISSUER_URL` | OIDC provider discovery URL |
| `OIDC_CLIENT_ID` | OAuth2 client ID |
| `OIDC_CLIENT_SECRET` | OAuth2 client secret |
| `OIDC_REDIRECT_URI` | Callback URL (e.g. `http://localhost:5678/auth/oidc/callback`) |

### Optional

| Variable | Default | Description |
|---|---|---|
| `OIDC_NAME` | `Oauth` | Label shown on the SSO login button |
| `GENERIC_TIMEZONE` | `Asia/Bangkok` | Timezone for workflows |
| `N8N_PROTOCOL` | `http` | Set to `https` behind a reverse proxy |
| `DOMAIN_NAME` | `localhost` | Top-level domain |
| `NODE_TLS_REJECT_UNAUTHORIZED` | `0` | Set to `0` to disable SSL verification (dev only) |

## OIDC Authentication

Authentication is handled by [n8n/hooks.js](n8n/hooks.js), which registers custom routes:

| Route | Description |
|---|---|
| `GET /auth/oidc/login` | Redirects to the OIDC provider |
| `GET /auth/oidc/callback` | Handles the authorization code callback |
| `GET /assets/oidc-frontend-hook.js` | Frontend script that replaces the login form with an SSO button |

### Login Flow

1. User visits `/signin` — the login form is replaced by a **Sign in with `OIDC_NAME`** button.
2. Clicking the button redirects to the OIDC provider.
3. After authentication, the provider redirects back to `/auth/oidc/callback`.
4. The hook exchanges the code for tokens, fetches user info, and creates the user in n8n if not found (first user becomes owner).
5. User is redirected to the n8n dashboard.

> To access the standard email/password login, append `?showLogin=true` to the signin URL.

### SSL Verification

SSL verification is disabled for OIDC requests (`rejectUnauthorized: false` in `hooks.js` and `NODE_TLS_REJECT_UNAUTHORIZED=0` in `.env`). This is intended for internal/development environments with self-signed certificates. Remove these settings in production.

## Volumes

| Volume | Description |
|---|---|
| `n8n_data` | n8n workflows, credentials, and settings |
| `n8n_postgres_data` | PostgreSQL database |
