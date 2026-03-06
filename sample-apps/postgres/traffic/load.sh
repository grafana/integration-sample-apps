#!/usr/bin/env bash
# Continuous realistic PostgreSQL traffic generator.
# Runs as the postgres OS user against the local postgres instance.
# Usage: sudo -u postgres bash /path/to/load.sh [duration_seconds]

set -euo pipefail

PGDB="${PGDB:-postgres}"
PGUSER="${PGUSER:-postgres}"
DURATION="${1:-3600}"  # default: run for 1 hour

psql() { command psql -U "$PGUSER" -d "$PGDB" -q "$@"; }
psql_out() { command psql -U "$PGUSER" -d "$PGDB" -tAq "$@"; }

END=$((SECONDS + DURATION))

echo "Starting traffic generator. Running for ${DURATION}s against db=${PGDB} user=${PGUSER}"

workload_new_order() {
    local user_id product_id qty price order_id total
    user_id=$(psql_out -c "SELECT id FROM users WHERE status='active' ORDER BY random() LIMIT 1;")
    [ -z "$user_id" ] && return

    order_id=$(psql_out -c "INSERT INTO orders (user_id, status) VALUES ($user_id, 'pending') RETURNING id;")

    total=0
    for _ in $(seq 1 $((1 + RANDOM % 4))); do
        read -r product_id price < <(psql_out -c "SELECT id, price FROM products WHERE stock > 0 ORDER BY random() LIMIT 1;" | tr '|' ' ')
        [ -z "$product_id" ] && continue
        qty=$((1 + RANDOM % 5))
        psql -c "
            INSERT INTO order_items (order_id, product_id, quantity, unit_price)
            VALUES ($order_id, $product_id, $qty, $price);
            UPDATE products SET stock = GREATEST(0, stock - $qty) WHERE id = $product_id;
        "
        total=$(echo "$total + $qty * $price" | bc)
    done

    psql -c "UPDATE orders SET total = $total WHERE id = $order_id;"
}

workload_process_orders() {
    psql -c "
        UPDATE orders SET status = 'processing', updated_at = NOW()
        WHERE status = 'pending'
          AND created_at < NOW() - interval '1 minute'
          AND id IN (SELECT id FROM orders WHERE status='pending' ORDER BY random() LIMIT 5);
    "
    psql -c "
        UPDATE orders SET status = 'shipped', updated_at = NOW()
        WHERE status = 'processing'
          AND id IN (SELECT id FROM orders WHERE status='processing' ORDER BY random() LIMIT 3);
    "
    psql -c "
        UPDATE orders SET status = 'delivered', updated_at = NOW()
        WHERE status = 'shipped'
          AND id IN (SELECT id FROM orders WHERE status='shipped' ORDER BY random() LIMIT 3);
    "
}

workload_cancel_orders() {
    psql -c "
        UPDATE orders SET status = 'cancelled', updated_at = NOW()
        WHERE status = 'pending'
          AND id IN (SELECT id FROM orders WHERE status='pending' ORDER BY random() LIMIT 2);
    "
}

workload_reads() {
    # Hot path: recent orders for a random user
    local user_id
    user_id=$(psql_out -c "SELECT id FROM users ORDER BY random() LIMIT 1;")
    [ -z "$user_id" ] && return

    psql -c "
        SELECT o.id, o.status, o.total, COUNT(oi.id) AS items
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.id
        WHERE o.user_id = $user_id
        GROUP BY o.id, o.status, o.total
        ORDER BY o.created_at DESC
        LIMIT 10;
    " > /dev/null

    # Aggregation query (hits stat_database)
    psql -c "
        SELECT category, COUNT(*) AS products, AVG(price)::numeric(10,2) AS avg_price, SUM(stock) AS total_stock
        FROM products
        GROUP BY category
        ORDER BY total_stock DESC;
    " > /dev/null

    # Join across all tables
    psql -c "
        SELECT u.name, COUNT(DISTINCT o.id) AS orders, SUM(o.total)::numeric(10,2) AS revenue
        FROM users u
        JOIN orders o ON o.user_id = u.id
        WHERE o.status = 'delivered'
          AND o.created_at > NOW() - interval '7 days'
        GROUP BY u.name
        ORDER BY revenue DESC
        LIMIT 20;
    " > /dev/null
}

workload_user_churn() {
    # Deactivate random users
    psql -c "
        UPDATE users SET status = 'inactive', updated_at = NOW()
        WHERE id IN (SELECT id FROM users WHERE status='active' ORDER BY random() LIMIT 2);
    "
    # Reactivate some
    psql -c "
        UPDATE users SET status = 'active', updated_at = NOW()
        WHERE id IN (SELECT id FROM users WHERE status='inactive' ORDER BY random() LIMIT 3);
    "
}

workload_restock() {
    psql -c "
        UPDATE products SET stock = stock + (50 + (random()*200)::int)
        WHERE id IN (SELECT id FROM products WHERE stock < 50 ORDER BY random() LIMIT 10);
    "
}

workload_deadlock_safe() {
    # Two updates in a transaction that could race but won't deadlock
    # because we always order by id asc
    psql -c "
        BEGIN;
        UPDATE products SET stock = stock + 1
        WHERE id IN (SELECT id FROM products ORDER BY id LIMIT 5)
        FOR UPDATE;
        UPDATE products SET stock = stock - 1
        WHERE id IN (SELECT id FROM products ORDER BY id LIMIT 5)
        FOR UPDATE;
        COMMIT;
    "
}

workload_cleanup() {
    psql -c "
        DELETE FROM order_items
        WHERE order_id IN (
            SELECT id FROM orders WHERE status='cancelled'
            AND created_at < NOW() - interval '15 minutes'
            LIMIT 5
        );
    "
    psql -c "
        DELETE FROM orders WHERE status='cancelled'
        AND created_at < NOW() - interval '15 minutes'
        AND id NOT IN (SELECT DISTINCT order_id FROM order_items)
        LIMIT 5;
    "
}

# Weights: higher = more frequent
WORKLOADS=(
    workload_reads workload_reads workload_reads workload_reads workload_reads
    workload_new_order workload_new_order workload_new_order
    workload_process_orders workload_process_orders
    workload_cancel_orders
    workload_user_churn
    workload_restock
    workload_deadlock_safe
    workload_cleanup
)

i=0
while [ $SECONDS -lt $END ]; do
    fn="${WORKLOADS[$((RANDOM % ${#WORKLOADS[@]}))]}"
    $fn 2>/dev/null || true

    i=$((i + 1))
    if [ $((i % 50)) -eq 0 ]; then
        echo "[$(date -u +%H:%M:%S)] $i ops completed, $((END - SECONDS))s remaining"
    fi

    # Variable sleep: mostly fast, occasional pause
    if [ $((RANDOM % 10)) -eq 0 ]; then
        sleep $((1 + RANDOM % 3))
    else
        sleep 0.2
    fi
done

echo "Traffic generator finished after $i operations."
