# E-Shop Data Engineering Pipeline

Учебный пет-проект — полноценный data engineering стек для интернет-магазина электроники. Включает генерацию данных, CDC-стриминг, батч-обработку, трансформации и визуализацию.

---

## Содержание

- [Архитектура](#архитектура)
- [Стек технологий](#стек-технологий)
- [Схема данных](#схема-данных)
- [Пайплайны](#пайплайны)
- [Быстрый старт](#быстрый-старт)
- [Доступ к сервисам](#доступ-к-сервисам)

---

## Архитектура

Проект реализует два пути доставки данных из источника в аналитическое хранилище:

```
PostgreSQL (источник)
    │
    ├── [Batch] Airflow DAG ──────────────────────────────────────────────────┐
    │              │                                                           │
    │         генерация данных                                                 │
    │         (Faker: users, products, orders)                                 │
    │                                                                          ▼
    └── [Streaming] Debezium CDC → Kafka → MinIO                         ClickHouse
                                               │                              │
                                            Spark                             │
                                               └──────────────────────────────┤
                                                                               │
                                               dbt (staging → intermediate → marts)
                                                                               │
                                                                          Superset
                                                                       (дашборды)
```

### Поток данных

**Batch-путь:**
1. Airflow DAG `mock_data_eshop` каждую минуту генерирует пользователей, заказы и позиции заказов через Faker
2. Данные записываются напрямую в PostgreSQL схему `eshop`
3. Airflow DAG `dbt_eshop` ожидает завершения генерации и запускает dbt в Docker-контейнере
4. dbt трансформирует сырые данные через слои staging → intermediate → marts в PostgreSQL (в будущем ClickHouse)

**Streaming-путь:**
To be done
---

## Стек технологий

| Компонент | Технология | Назначение |
|-----------|-----------|------------|
| Источник данных | PostgreSQL 14 | OLTP-хранилище магазина |
| Оркестрация | Apache Airflow | Управление пайплайнами |
| CDC | Debezium 2.7 | Change Data Capture из PostgreSQL |
| Брокер сообщений | Apache Kafka | Стриминг событий |
| Объектное хранилище | MinIO | S3-совместимое хранилище для raw-данных |
| Batch-обработка | Apache Spark 3.5 | Трансформации и агрегации |
| Аналитическая БД | ClickHouse 23.10 | OLAP-хранилище |
| Трансформации | dbt | SQL-модели, тесты, документация |
| Визуализация | Apache Superset | Дашборды и отчёты |
| Разработка | Jupyter + PySpark | Исследование данных |

---

## Схема данных

### PostgreSQL — схема `eshop` (источник)

```
┌──────────────────┐         ┌──────────────────────┐
│     users        │         │      products        │
├──────────────────┤         ├──────────────────────┤
│ id (PK)          │         │ id (PK)              │
│ name             │         │ name (UNIQUE)         │
│ surname          │         │ category             │
│ email (UNIQUE)   │         │ price (> 0)          │
│ birthdate        │         │ description          │
└────────┬─────────┘         └──────────┬───────────┘
         │                              │
         │ 1:N                          │ 1:N
         ▼                              ▼
┌──────────────────┐         ┌──────────────────────┐
│     orders       │         │   orders_products    │
├──────────────────┤         ├──────────────────────┤
│ id (PK)          │◄────────│ order_id (PK, FK)    │
│ user_id (FK)     │   N:M   │ product_id (PK, FK)──┘
│ order_timestamp  │         │ quantity (> 0)       │
│ delivery_city    │         └──────────────────────┘
└──────────────────┘
```


Каждый слой отвечает за свой уровень абстракции:
- **staging** — сырые данные из PostgreSQL, минимальные трансформации
- **intermediate** — промежуточные агрегации и обогащения
- **marts** — витрины данных, готовые для дашбордов

---

## Пайплайны

### DAG: `mock_data_eshop`

Генерация синтетических данных через Faker (локаль `ru_RU`).

```
check_postgres_connection
         │
    data_init
    (create_tables.sql)
         │
    ┌────┴─────────────────────────────────┐
    │           data_gen (TaskGroup)       │
    │                                      │
    │  users_gen → products_gen → orders_gen → orders_products_gen  │
    └──────────────────────────────────────┘
```

| Задача | Описание |
|--------|----------|
| `check_postgres_connection` | Проверяет подключение, создаёт схему `eshop` |
| `data_init` | Создаёт таблицы если не существуют |
| `users_gen` | Генерирует 5 пользователей за запуск |
| `products_gen` | Заполняет каталог товаров из SQL-файла |
| `orders_gen` | Генерирует 10 заказов за запуск |
| `orders_products_gen` | Генерирует 100 позиций заказов |

Расписание: каждую минуту (`* * * * *`)

---

### DAG: `dbt_eshop`

Запускает dbt-трансформации в изолированном Docker-контейнере.

```
wait_for_data_gen
(ExternalTaskSensor → mock_data_eshop)
         │
      dbt_run
   (DockerOperator)
         │
      dbt_test
   (DockerOperator)
```

| Задача | Описание |
|--------|----------|
| `wait_for_data_gen` | Ждёт успешного завершения `mock_data_eshop` |
| `dbt_run` | Запускает все dbt-модели в контейнере `de1-dbt` |
| `dbt_test` | Прогоняет dbt-тесты для контроля качества данных |

Расписание: каждую минуту (`* * * * *`), после завершения генерации данных

---

## Быстрый старт

### Требования

- Docker Desktop
- Docker Compose
- 8+ GB RAM (рекомендуется)

### Запуск

```bash
# Клонировать репозиторий
git clone <repo-url>
cd de1

# Собрать и запустить все сервисы
docker-compose up -d --build

# Инициализировать Superset (при первом запуске)
docker exec -it superset superset db upgrade
docker exec -it superset superset fab create-admin \
  --username admin --firstname Admin --lastname User \
  --email admin@example.com --password admin
docker exec -it superset superset init

# Проверить статус сервисов
docker-compose ps
```

### Настройка Airflow

1. Открыть http://localhost:8080 (admin / admin)
2. Создать подключение `postgres_src`:
   - **Conn Type:** Postgres
   - **Host:** `postgres-srcq`
   - **Port:** `5432`
   - **Database:** `mydb`
   - **Login:** `postgres`
   - **Password:** `postgres`
3. Включить DAG `mock_data_eshop`, затем `dbt_eshop`

### Настройка Superset

1. Открыть http://localhost:8088 (admin / admin)
2. Добавить подключение к PostgreSQL:
   - **Host:** `postgres-srcq`, **Port:** `5432`
   - **Database:** `mydb`, **User:** `postgres`, **Password:** `postgres`
3. Добавить подключение к ClickHouse:
   - **SQLAlchemy URI:** `clickhousedb://default@clickhouse:8123/default`

---

## Доступ к сервисам

| Сервис | URL | Логин / Пароль |
|--------|-----|----------------|
| Airflow | http://localhost:8080 | admin / admin |
| Superset | http://localhost:8088 | admin / admin |
| Kafka UI | http://localhost:8082 | — |
| MinIO Console | http://localhost:9001 | minio / minio123 |
| Spark UI | http://localhost:8081 | — |
| Jupyter | http://localhost:8889 | token: `admin` |
| dbt docs | http://localhost:8086 | — |
| Debezium REST API | http://localhost:8083 | — |
| ClickHouse HTTP | http://localhost:8123 | default / (без пароля) |
| PostgreSQL | localhost:5433 | postgres / postgres |