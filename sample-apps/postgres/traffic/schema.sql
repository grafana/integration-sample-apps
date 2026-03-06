-- Schema for realistic PostgreSQL traffic generation

CREATE TABLE IF NOT EXISTS users (
    id          SERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'banned')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    category    TEXT NOT NULL,
    price       NUMERIC(10, 2) NOT NULL,
    stock       INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id),
    status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    total       NUMERIC(10, 2) NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
    id          SERIAL PRIMARY KEY,
    order_id    INTEGER NOT NULL REFERENCES orders(id),
    product_id  INTEGER NOT NULL REFERENCES products(id),
    quantity    INTEGER NOT NULL,
    unit_price  NUMERIC(10, 2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id   ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status     ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_users_status      ON users(status);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- Seed data
INSERT INTO users (email, name, status)
SELECT
    'user' || i || '@example.com',
    'User ' || i,
    (ARRAY['active','active','active','inactive','banned'])[1 + (random()*4)::int]
FROM generate_series(1, 500) AS i
ON CONFLICT DO NOTHING;

INSERT INTO products (name, category, price, stock)
SELECT
    'Product ' || i,
    (ARRAY['electronics','clothing','food','books','sports'])[1 + (random()*4)::int],
    (random() * 500 + 1)::numeric(10,2),
    (random() * 1000)::int
FROM generate_series(1, 200) AS i
ON CONFLICT DO NOTHING;

-- Seed some orders
DO $$
DECLARE
    v_user_id   INTEGER;
    v_order_id  INTEGER;
    v_product_id INTEGER;
    v_qty       INTEGER;
    v_price     NUMERIC(10,2);
    v_total     NUMERIC(10,2);
BEGIN
    FOR i IN 1..300 LOOP
        SELECT id INTO v_user_id FROM users ORDER BY random() LIMIT 1;
        INSERT INTO orders (user_id, status, created_at)
        VALUES (
            v_user_id,
            (ARRAY['pending','processing','shipped','delivered','cancelled'])[1 + (random()*4)::int],
            NOW() - (random() * interval '30 days')
        )
        RETURNING id INTO v_order_id;

        v_total := 0;
        FOR j IN 1..(1 + (random()*4)::int) LOOP
            SELECT id, price INTO v_product_id, v_price FROM products ORDER BY random() LIMIT 1;
            v_qty := 1 + (random()*5)::int;
            INSERT INTO order_items (order_id, product_id, quantity, unit_price)
            VALUES (v_order_id, v_product_id, v_qty, v_price);
            v_total := v_total + v_qty * v_price;
        END LOOP;

        UPDATE orders SET total = v_total WHERE id = v_order_id;
    END LOOP;
END;
$$;
