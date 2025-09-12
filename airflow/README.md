# Airflow v3
1. create image

```
docker build -t my-airflow .
```

2. start airflow
```
docker compose up
```

3. open browser http://localhost:8080
- username : admin
- password : admin

4. tigger dag

## Noti email

add variable
- SITE_NAME [str] : Site name for email title
- DSM_EMAIL_URI [str] : https://email-service.data.storemesh.com
- DSM_EMAIL_APIKEY [str] : ApiKey for dsm email services
- ALERT_EMAILS [array[str]] : Email for notice if pipeline error

install package
```
pip install dsm-services==0.0.13
```