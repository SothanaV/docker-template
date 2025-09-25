# ZAP Scan
- run via docker

    1. edit `config/run-zap-web.sh`
    ```sh
    ./zap-baseline.py -t <URI> -r zap-report-web.html -a > /zap/wrk/zap-web.log
    curl -X POST <ZAP_SERVER_URI>/upload/ -F "project=<PROJECT_ID>" -F "file=@/zap/wrk/zap-web.log"
    curl -X POST <ZAP_SERVER_URI>/upload/ -F "project=<PROJECT_ID>" -F "file=@/zap/wrk/zap-report-web.html"
    ```
    2. run
    ```
    docker compose up
    ```
- run via gitlab-ci
```yml
stages:
    ...
    - scan
    ...

zap-scan:
    stage: scan
    image: zaproxy/zap-stable:2.16.0
    script:
      - mkdir -p /zap/wrk
      - /zap/zap-baseline.py -t <URI> -r zap-report-web.html -a > /zap/wrk/zap-web.log || true
      - curl -X POST <ZAP_SERVER_URI>/upload/ -F "project=<PROJECT_ID>" -F "file=@/zap/wrk/zap-web.log"
      - curl -X POST <ZAP_SERVER_URI>/upload/ -F "project=<PROJECT_ID>" -F "file=@/zap/wrk/zap-report-web.html"
```