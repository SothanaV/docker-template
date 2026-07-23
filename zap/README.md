# OWASP ZAP

A Docker Compose template for [OWASP ZAP](https://www.zaproxy.org/) v2.16.0 — an open-source web application security scanner.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

## Usage

### Run via Docker Compose

1. Edit `./config/run-zap-web.sh` to set your target and upload endpoints:

```sh
./zap-baseline.py -t <TARGET_URI> -r zap-report-web.html -a > /zap/wrk/zap-web.log
curl -X POST <ZAP_SERVER_URI>/upload/ -F "project=<PROJECT_ID>" -F "file=@/zap/wrk/zap-web.log"
curl -X POST <ZAP_SERVER_URI>/upload/ -F "project=<PROJECT_ID>" -F "file=@/zap/wrk/zap-report-web.html"
```

2. Run the scan:

```bash
docker compose up
```

Scan output (log and HTML report) is saved to `./output/`.

### Run via GitLab CI

Add a scan stage to your `.gitlab-ci.yml`:

```yaml
stages:
  - scan

zap-scan:
  stage: scan
  image: zaproxy/zap-stable:2.16.0
  script:
    - mkdir -p /zap/wrk
    - /zap/zap-baseline.py -t <TARGET_URI> -r zap-report-web.html -a > /zap/wrk/zap-web.log || true
    - curl -X POST <ZAP_SERVER_URI>/upload/ -F "project=<PROJECT_ID>" -F "file=@/zap/wrk/zap-web.log"
    - curl -X POST <ZAP_SERVER_URI>/upload/ -F "project=<PROJECT_ID>" -F "file=@/zap/wrk/zap-report-web.html"
```

## Services

| Service   | Image                        | Output             |
|-----------|------------------------------|--------------------|
| `zap-web` | `zaproxy/zap-stable:2.16.0`  | `./output/`        |

## Project Structure

```
zap/
├── config/
│   └── run-zap-web.sh    # ZAP scan script (edit target URI here)
├── output/               # Scan results (log + HTML report)
└── docker-compose.yml
```
