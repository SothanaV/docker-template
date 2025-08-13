# Airflow
- requirements.txt
```
...
# airflow
apache-airflow==2.4.1
Flask-Session==0.4.0
sqlalchemy==1.4.36
psycopg2-binary==2.9.9
triad==0.9.8
pendulum==2.1.2
apache-airflow[kubernetes]
statsd==4.0.1
...
```

- Dockerfile
```Dockerfile
FROM apache/airflow:slim-2.4.1-python3.10
USER root
RUN apt-get update --fix-missing && \
    apt-get install -y git netcat-traditional curl iputils-ping gcc unzip wget && \
    rm -rf /var/lib/apt/lists/*


USER airflow
COPY ./<PIPELINE_DIR>/requirements.txt /requirements.txt

RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r /requirements.txt

COPY ./<PIPELINE_DIR> /opt/airflow/dags
```

- Dags.py
    - create dag
    ```
    kedro airflow create --target-dir ./airflow_dags/ --pipeline <PIPELINE_NAME>
    ```

    - edit dag
    ```py
    from kedro.framework.startup import bootstrap_project

    class KedroOperator(BaseOperator):
        ...

        def execute(self, context):
            bootstrap_project(project_path)
            print(f"""{'#'*10}\t context {context} \t {'#'*10}""")
            etl_date = context["next_ds"]
            print(f"\t etl_date : {etl_date}")

            with KedroSession.create(
            ...
                extra_params={
                    'etl_date': etl_date
                }
            ) as session:
            ...

    ...
    path_source = "/opt/airflow/dags"
    project_path = path_source
    conf_source = f'{path_source}/conf'
    ...
    ```