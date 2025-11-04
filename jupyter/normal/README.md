# Jupyter on Docker
1. edit `.env`

    ```sh
    PROJECT_NAME=jupyter
    JUPYTER_PASSWORD='qwer1234'
    ```
2. docker up
    ```
    docker compose up
    ```

## If use duckdb connect object storage
create db connection
- Supported databases: Other
- DisplyName : Duckdb
- SQLAlchemy URI: `duckdb:///:memory:`
- Tab Advance > Other > Engine Parameters
    ```json
    {
        "connect_args":{
            "preload_extensions":["httpfs"],
            "config":{
                "s3_endpoint":"minio:9000",   
                "s3_access_key_id":"minio",
                "s3_secret_access_key":"minioqwer1234",
                "s3_url_style":"path",   
                "s3_use_ssl":"False"
            }
        }
    }
    ```