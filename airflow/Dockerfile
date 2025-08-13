# FROM apache/airflow:slim-2.10.5-python3.12
FROM apache/airflow:slim-3.0.2-python3.12


USER root
RUN apt-get update --fix-missing && \
    apt-get install -y git netcat-traditional curl iputils-ping libpq-dev gcc unzip wget libaio1 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/airflow

USER airflow
COPY ./etl-pipeline/requirements-airflow.txt /requirements-airflow.txt
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r /requirements-airflow.txt

COPY ./etl-pipeline/requirements.txt /requirements.txt
RUN pip install virtualenv
RUN python -m venv /home/airflow/venv && \
    source /home/airflow/venv/bin/activate &&\
    pip install -r /requirements.txt && \
    ls /home/airflow/venv/bin/activate

COPY ./etl-pipeline /opt/airflow/dags

USER root
RUN chmod -R 777 /opt/airflow/dags

USER airflow