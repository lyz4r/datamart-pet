        -- Создаем схему для наших таблиц (опционально)
        CREATE SCHEMA IF NOT EXISTS eshop;
        
        -- Таблицы в схеме eshop
        CREATE TABLE IF NOT EXISTS eshop.users
        (
            id SERIAL PRIMARY KEY,
            name VARCHAR(50) NOT NULL,
            surname VARCHAR(50) NOT NULL,
            email VARCHAR(50) UNIQUE,
            birthdate DATE
        );

        CREATE TABLE IF NOT EXISTS eshop.products
        (
            id SERIAL PRIMARY KEY,
            name VARCHAR(50) UNIQUE,
            category VARCHAR(50),
            price NUMERIC CHECK (price > 0),
            description TEXT
        );

        CREATE TABLE IF NOT EXISTS eshop.orders
        (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL, 
            order_timestamp TIMESTAMP NOT NULL,
            delivery_city VARCHAR(50),
            CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES eshop.users(id)  
        );

        CREATE TABLE IF NOT EXISTS eshop.orders_products
        (
            order_id INTEGER NOT NULL, 
            product_id INTEGER NOT NULL, 
            quantity INT CHECK (quantity > 0),
            PRIMARY KEY (order_id, product_id),
            CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES eshop.orders(id),
            CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES eshop.products(id)
        );
        