from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import ExternalPythonOperator
from airflow.models import Variable

from dsm_services.airflow import utils as email_utils
import dsmemail

DSM_EMAIL_URI = Variable.get("DSM_EMAIL_URI", default_var="https://email-service.data.storemesh.com", deserialize_json=False) 
DSM_EMAIL_APIKEY = Variable.get("DSM_EMAIL_APIKEY", default_var="API_KEY", deserialize_json=False)
SITE_NAME = Variable.get("SITE_NAME", default_var='', deserialize_json=False)
ALERT_EMAILS = Variable.get("ALERT_EMAILS", default_var='[]', deserialize_json=True)

def run(
    fn,
    **kwargs
):
    from importlib import import_module
    import sys

    sys.path.append('/opt/airflow/dags/dags')
    
    def import_from_string(dotted_path):
        module_path, attr_name = dotted_path.rsplit('.', 1)
        module = import_module(module_path)
        return getattr(module, attr_name)
    
    print(f"kwargs : {kwargs}")
    func = import_from_string(fn)
    func()



def task_failure_alert(context):
    print(context)
    print(ALERT_EMAILS)

    subject, body = email_utils.create_notice_email(site_name=SITE_NAME, context=context)
    status = dsmemail.sendEmail(
        subject=subject, 
        message=body, 
        emails=ALERT_EMAILS,
        host=DSM_EMAIL_URI,
        api_key=DSM_EMAIL_APIKEY
    )
    print(status)

    

venv_cache_path = "/home/airflow/venv/"

with DAG(
    dag_id="test-email",
    start_date=datetime(2023,1,1),
    max_active_runs=3,
    # https://airflow.apache.org/docs/stable/scheduler.html#dag-runs
    schedule="* * * * *",
    catchup=False,
    # Default settings applied to all tasks
    default_args=dict(
        owner="airflow",
        depends_on_past=False,
        email_on_failure=False,
        email_on_retry=False,
        retries=0,
        retry_delay=timedelta(seconds=5),
        on_failure_callback=task_failure_alert
    )
) as dag:
    tasks = {

        "hello": ExternalPythonOperator(
            task_id="hello",
            python_callable=run,
            python="/home/airflow/venv/bin/python",
            op_kwargs={
                "fn": 'mycode.hello.hello',
            }
        ),
        "hi": ExternalPythonOperator(
            task_id="hi",
            python_callable=run,
            python="/home/airflow/venv/bin/python",
            op_kwargs={
                "fn": 'mycode.hello.hi',
            }
        ),
        "noti": ExternalPythonOperator(
            task_id="noti",
            python_callable=run,
            python="/home/airflow/venv/bin/python",
            op_kwargs={
                "fn": 'mycode.noti.ran_err',
            }
        ),

    }

    tasks["hello"] >> tasks["hi"]

