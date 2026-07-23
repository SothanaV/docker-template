# Airflow v3

A Docker Compose template for [Apache Airflow](https://airflow.apache.org/) 3.0 — a platform for authoring, scheduling, and monitoring data pipelines.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Quick Start

1. Build the custom image:

```bash
docker build -t my-airflow .
```

1. Start Airflow:

```bash
docker compose up -d
```

1. Open the UI at <http://localhost:8080>
   - Username: `admin`
   - Password: `admin`

1. Trigger a DAG from the UI.

## Services

| Service                 | Image / Build           | Port | Description                   |
|-------------------------|-------------------------|------|-------------------------------|
| `postgres`              | `postgres:17.5-alpine`  | —    | Airflow metadata database     |
| `airflow-apiserver`     | `my-airflow`            | 8080 | Web UI & API server           |
| `airflow-scheduler`     | `my-airflow`            | —    | Schedules and queues DAG runs |
| `airflow-dag-processor` | `my-airflow`            | —    | Processes DAG files           |

## Networks

| Network    | Type     | Used By                   |
|------------|----------|---------------------------|
| `internal` | internal | All services (isolated)   |
| `kedro`    | external | `airflow-scheduler` only  |

## Email Notifications

Add these Airflow variables in the UI (**Admin → Variables**):

| Variable           | Type           | Description                            |
|--------------------|----------------|----------------------------------------|
| `SITE_NAME`        | string         | Site name used in email subject        |
| `DSM_EMAIL_URI`    | string         | Email service base URL                 |
| `DSM_EMAIL_APIKEY` | string         | API key for the email service          |
| `ALERT_EMAILS`     | array[string]  | Recipients for pipeline failure alerts |

Install the notification package in the custom image:

```bash
pip install dsm-services==0.0.13
```

## OAuth Sign-In

To enable OAuth2 login, update `airflow-requirements.txt`:

```text
apache-airflow-providers-fab==2.4.2
Authlib==1.6.4
Flask-Limiter==3.12
```

Mount `webserver_config.py` to `/opt/airflow/webserver_config.py` (already configured in `docker-compose.yml`). Update the `client_id` and `client_secret` in that file with your OAuth2 provider credentials.

## Stop

```bash
docker compose down
```
