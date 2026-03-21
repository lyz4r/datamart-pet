"""
DAG для Datamart розничного электронного магазина
"""

from airflow import DAG
from datetime import datetime, timedelta
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.utils.task_group import TaskGroup
from faker import Faker
from random import randrange


def check_connection():
    """Проверяем доступные подключения"""
    hook = PostgresHook(postgres_conn_id="postgres_src")
    conn = hook.get_conn()
    cursor = conn.cursor()
    cursor.execute("SELECT current_database(), current_schema;")
    db, schema = cursor.fetchone()
    print(f"Connected to database: {db}, schema: {schema}")

    # Создаем схему для наших таблиц
    cursor.execute("CREATE SCHEMA IF NOT EXISTS eshop;")
    conn.commit()
    print("Schema 'eshop' created or already exists")


def generate_users():
    fake = Faker('ru_RU')

    try:
        hook = PostgresHook(postgres_conn_id="postgres_src")
        conn = hook.get_conn()
        cursor = conn.cursor()

        # Подготавливаем данные для пакетной вставки
        users_data = []
        for _ in range(5):
            users_data.append((
                fake.first_name(),
                fake.last_name(),
                fake.email(),
                fake.date_time_between(start_date='-70y', end_date='-14y'),
            ))

        # Пакетная вставка с помощью executemany
        cursor.executemany("""
            INSERT INTO eshop.users 
            (name, surname, email, birthdate)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (email) DO NOTHING
        """, users_data)

        conn.commit()

        # Проверяем, сколько реально добавилось
        cursor.execute("SELECT COUNT(*) FROM eshop.users")
        total_users = cursor.fetchone()[0]
        print(
            f"Всего пользователей: {total_users}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"Ошибка при генерации пользователей: {e}")
        raise


def generate_products():
    try:
        hook = PostgresHook(postgres_conn_id="postgres_src")
        conn = hook.get_conn()
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(id) FROM eshop.products;")
        if cursor.fetchone():
            return
        cursor.execute("queries/insert_products.sql")
        cursor.execute("SELECT COUNT(id) FROM eshop.products;")
        count = cursor.fetchone()
        print(f"Выполнена вставка {count} новых товаров.")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"Ошибка при добавлении товаров: {e}")
        raise


def generate_orders():
    fake = Faker('ru_RU')

    try:
        hook = PostgresHook(postgres_conn_id="postgres_src")
        conn = hook.get_conn()
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) FROM eshop.users;")
        user_count = cursor.fetchone()[0]

        orders = []
        for _ in range(10):  # создаём 10 заказов
            orders.append((
                randrange(1, user_count),
                fake.date_time_between("-7d", "now"),
                fake.city_name(),
            ))

        cursor.executemany("""
                           INSERT INTO eshop.orders
                           (user_id, order_timestamp, delivery_city)
                           VALUES (%s, %s, %s)
                           """, orders)

        conn.commit()

        # Проверяем, сколько реально добавилось
        cursor.execute("SELECT COUNT(*) FROM eshop.orders")
        total_orders = cursor.fetchone()[0]
        print(
            f"Всего заказов: {total_orders}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"Ошибка при добавлении заказов: {e}")
        raise


def generate_orders_products():

    try:
        hook = PostgresHook(postgres_conn_id="postgres_src")
        conn = hook.get_conn()
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) FROM eshop.orders;")
        order_count = cursor.fetchone()[0]
        cursor.execute("SELECT MIN(id) FROM eshop.orders;")
        min_id_orders = cursor.fetchone()[0]

        orders_products = []
        for _ in range(100):  # создаём 100 единиц заказанных товаров
            orders_products.append((
                randrange(min_id_orders, min_id_orders + order_count),
                randrange(1, 100),
                randrange(1, 3),
            ))

        cursor.executemany("""
                           INSERT INTO eshop.orders_products
                           (order_id, product_id, quantity)
                           VALUES (%s, %s, %s)
                           ON CONFLICT (order_id, product_id) DO NOTHING
                           """, orders_products)

        conn.commit()

        # Проверяем, сколько реально добавилось
        cursor.execute("SELECT COUNT(*) FROM eshop.orders_products")
        total_orders = cursor.fetchone()[0]
        print(
            f"Всего связок товаров с заказами: {total_orders}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"Ошибка при добавлении связки товаров и заказов: {e}")
        raise


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'retries': 2,
    'retry_delay': timedelta(seconds=10),
}

with DAG(
    'eshop_dag',
    default_args=default_args,
    description='DAG для генерации и визуализации данных розничного онлайн-магазина',
    schedule_interval='@daily',
    start_date=datetime(2026, 3, 18),
    catchup=False,
    tags=['eshop'],
) as dag:

    with TaskGroup("data_gen") as data_gen:

        users_gen = PythonOperator(
            task_id='users_gen',
            python_callable=generate_users
        )

        products_gen = PythonOperator(
            task_id='products_gen',
            python_callable=generate_products
        )

        orders_gen = PythonOperator(
            task_id='orders_gen',
            python_callable=generate_orders
        )

        orders_products_gen = PythonOperator(
            task_id='orders_products_gen',
            python_callable=generate_orders_products
        )

        users_gen >> products_gen >> orders_gen >> orders_products_gen

    check_conn = PythonOperator(
        task_id='check_postgres_connection',
        python_callable=check_connection
    )

    data_init = PostgresOperator(
        task_id="data_init",
        postgres_conn_id="postgres_src",
        sql="queries/create_tables.sql"
    )

    # Устанавливаем порядок выполнения
    check_conn >> data_init >> data_gen
