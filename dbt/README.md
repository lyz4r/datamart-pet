# 🛒 shop_analytics — dbt Project

Аналитический dbt-проект для розничного интернет-магазина электроники. Трансформирует сырые операционные данные из PostgreSQL в аналитические слои: staging → intermediate → marts.

---

## 📦 Стек

| Компонент | Версия |
|-----------|--------|
| dbt-core | 1.11.7 |
| dbt-postgres | 1.10.0 |
| PostgreSQL | 14 |

---

## 🗂️ Структура проекта

```
shop_analytics/
├── models/
│   ├── staging/          # Очистка и стандартизация сырых данных
│   ├── intermediate/     # Промежуточные агрегации (ephemeral)
│   └── marts/            # Финальные аналитические таблицы
├── tests/                # Data-тесты
├── seeds/                # Справочные данные
├── macros/               # Кастомные макросы
├── analyses/             # Ad-hoc SQL-запросы
└── dbt_project.yml
```

---

## 📐 Слои данных

### `staging` — представления (views)
Схема: `public_staging`

Один-к-одному с источником: переименование колонок, приведение типов, базовая фильтрация. Никакой бизнес-логики.

| Модель | Описание |
|--------|----------|
| `stg_orders` | Заказы из операционной БД |
| `stg_order_items` | Позиции заказов |
| `stg_products` | Каталог товаров |
| `stg_users` | Пользователи / покупатели |

### `intermediate` — ephemeral CTE
Промежуточные расчёты, которые встраиваются в mart-модели и не материализуются отдельно.

| Модель | Описание |
|--------|----------|
| `int_order_aggregates` | Агрегаты по заказам (сумма, кол-во позиций) |
| `int_user_metrics` | Метрики активности пользователей |

### `marts` — таблицы (tables)
Схема: `public_marts`

Готовые аналитические таблицы для BI-инструментов и отчётности.

| Модель | Описание |
|--------|----------|
| `fct_sales` | Факт продаж — детальная таблица транзакций |
| `dim_users` | Измерение пользователей с атрибутами |
| `kpi_daily_sales` | KPI: ежедневная выручка и количество заказов |
| `kpi_category_sales` | KPI: продажи по категориям товаров |

---

## 🚀 Быстрый старт

### Предварительные требования

- Docker и Docker Compose
- Запущенный контейнер `dbt` и `postgres-src`

### Установка зависимостей

```bash
docker exec -it dbt bash
dbt deps
```

### Запуск всех моделей

```bash
dbt run
```

### Запуск только mart-слоя

```bash
dbt run --select marts
```

### Запуск staging-слоя

```bash
dbt run --select staging
```

### Запуск конкретной модели и всех её зависимостей

```bash
dbt run --select +kpi_daily_sales
```

---

## ✅ Тесты

```bash
# Запуск всех тестов
dbt test

# Тесты только для staging
dbt test --select staging

# Тесты конкретной модели
dbt test --select fct_sales
```

Проект содержит **17 data-тестов** (not_null, unique, accepted_values, relationships).

---

## 📊 Документация

```bash
# Генерация документации
dbt docs generate

# Запуск сервера документации (доступен на хосте через порт 8086, 8080 конфликтует с Airflow)
dbt docs serve --port 8086 --host 0.0.0.0
```


## 🔌 Источники данных

Проект читает данные из **4 источников** в PostgreSQL (`postgres-src`, порт `5432`).  
Конфигурация подключения — в `profiles.yml` (профиль `shop_analytics`, target `dev`).

---

## 📁 Полезные команды

```bash
# Проверка подключения к БД
dbt debug

# Просмотр скомпилированного SQL модели
dbt compile --select fct_sales

# Очистка артефактов
dbt clean

# Полный цикл: тест источников + run + тесты
dbt source freshness
dbt run
dbt test
```

---

## 🗃️ Запросы к mart-таблицам

```sql
-- Подключение
psql -h localhost -p 5432 -U postgres -d postgres

-- Ежедневная выручка
SELECT * FROM public_marts.kpi_daily_sales ORDER BY date DESC;

-- Топ категорий по выручке
SELECT * FROM public_marts.kpi_category_sales ORDER BY total_revenue DESC;

-- Факт продаж (последние 20)
SELECT * FROM public_marts.fct_sales LIMIT 20;
```
