"""
DAG для запуска dbt розничного электронного магазина
"""

from airflow import DAG
from airflow.providers.docker.operators.docker import DockerOperator
from airflow.sensors.external_task import ExternalTaskSensor
from datetime import datetime
from docker.types import Mount


import os

project_dir = os.environ.get("HOST_PROJECT_DIR")

with DAG(
    dag_id="dbt_eshop",
    start_date=datetime(2026, 3, 18),
    schedule_interval="* * * * *",
    catchup=False,
    tags=['eshop'],
) as dag:

    wait_for_data = ExternalTaskSensor(
        task_id="wait_for_data_gen",
        external_dag_id="mock_data_eshop",
        mode="reschedule",
        timeout=600,
        poke_interval=30,
    )

    dbt_run = DockerOperator(
        task_id="dbt_run",
        image="datamart-pet-dbt",
        command="dbt run",
        working_dir="/usr/app",
        docker_url="unix://var/run/docker.sock",
        network_mode="datamart-pet_de_net",
        mount_tmp_dir=False,
        mounts=[
            Mount(
                source=f"{project_dir}/dbt",
                target="/usr/app",
                type="bind"
            ),
            Mount(
                source=f"{project_dir}/dbt/profiles.yml",
                target="/root/.dbt/profiles.yml",
                type="bind"
            ),
        ],
        auto_remove="success",
    )

    dbt_test = DockerOperator(
        task_id="dbt_test",
        image="datamart-pet-dbt",
        command="dbt test",
        working_dir="/usr/app",
        docker_url="unix://var/run/docker.sock",
        network_mode="datamart-pet_de_net",
        mount_tmp_dir=False,
        mounts=[
            Mount(
                source=f"{project_dir}/dbt",
                target="/usr/app",
                type="bind"
            ),
            Mount(
                source=f"{project_dir}/dbt/profiles.yml",
                target="/root/.dbt/profiles.yml",
                type="bind"
            ),
        ],
        auto_remove="success",
    )

    wait_for_data >> dbt_run >> dbt_test
