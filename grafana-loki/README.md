# Grafana Loki Docker Template

A Docker Compose setup for deploying [Grafana](https://grafana.com/) and [Loki](https://grafana.com/oss/loki/) for log management and visualization.

## Overview

This template provides a quick-start configuration with:
- **Grafana** (v11.4.0) – Unified observability platform with dashboards and UI
- **Loki** (v3.3.2) – Log aggregation system (promtail-compatible, like Prometheus for logs)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

### 1. Start the services

```bash
docker-compose up -d
```

### 2. Access Grafana

Open your browser and navigate to:
- **Grafana UI**: http://localhost:3000

Default credentials:
- **Username**: `admin`
- **Password**: `admin`

### 3. Configure Loki as a Data Source in Grafana

1. Go to **Connections** → **Add data source** → **Loki**
2. Set the URL to: `http://loki:3100`
3. Click **Save & Test**

### 4. Start Logging

You can now query logs in Grafana using LogQL or configure other services to ship logs to Loki.

## Project Structure

```
grafana-loki/
├── docker-compose.yaml   # Docker Compose configuration
└── README.md             # This file
```

## Volumes

| Volume          | Purpose                        |
|-----------------|--------------------------------|
| `loki_data`     | Stores Loki log data           |
| `grafana_data`  | Stores Grafana configurations  |

## Services

| Service    | Image                    | Port   | Volume            |
|------------|--------------------------|--------|-------------------|
| `loki`     | `grafana/loki:3.3.2`     | 3100   | `loki_data`       |
| `grafana`  | `grafana/grafana:11.4.0` | 3000   | `grafana_data`    |

## Stop the services

```bash
docker-compose down
```

To remove all data:

```bash
docker-compose down -v
```

## Customization

### Environment Variables

You can extend the `grafana` service with environment variables for configuration:

```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=your_secure_password
  - GF_USERS_ALLOW_SIGN_UP=false
```

### Persistent Configuration

To persist Grafana provisioning configs, mount additional directories:

```yaml
volumes:
  - ./provisioning:/etc/grafana/provisioning
```

## License

This project is available as a template for personal or commercial use.