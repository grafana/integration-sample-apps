#!/usr/bin/env bash
# Continuous PostgreSQL traffic generator with parallel workers and lock contention.
# Usage: sudo -u postgres bash /opt/traffic/load.sh [duration_seconds] [workers]

PGDB="${PGDB:-postgres}"
PGUSER="${PGUSER:-postgres}"
DURATION="${1:-3600}"
WORKERS="${2:-5}"

psql() { command psql -U "$PGUSER" -d "$PGDB" -q "$@"; }
psql_out() { command psql -U "$PGUSER" -d "$PGDB" -tAq "$@"; }

END=$((SECONDS + DURATION))

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
          AND id IN (SELECT id FROM orders WHERE status='pending' ORDER BY random() LIMIT 10);
    "
    psql -c "
        UPDATE orders SET status = 'shipped', updated_at = NOW()
        WHERE status = 'processing'
          AND id IN (SELECT id FROM orders WHERE status='processing' ORDER BY random() LIMIT 5);
    "
    psql -c "
        UPDATE orders SET status = 'delivered', updated_at = NOW()
        WHERE status = 'shipped'
          AND id IN (SELECT id FROM orders WHERE status='shipped' ORDER BY random() LIMIT 5);
    "
}

workload_cancel_orders() {
    psql -c "
        UPDATE orders SET status = 'cancelled', updated_at = NOW()
        WHERE status = 'pending'
          AND id IN (SELECT id FROM orders WHERE status='pending' ORDER BY random() LIMIT 5);
    "
}

workload_reads() {
    local user_id
    user_id=$(psql_out -c "SELECT id FROM users ORDER BY random() LIMIT 1;")
    [ -z "$user_id" ] && return
    psql -c "
        SELECT o.id, o.status, o.total, COUNT(oi.id) AS items
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.id
        WHERE o.user_id = $user_id
        GROUP BY o.id, o.status, o.total
        ORDER BY o.created_at DESC LIMIT 10;
    " > /dev/null
    psql -c "
        SELECT category, COUNT(*) AS products, AVG(price)::numeric(10,2) AS avg_price, SUM(stock) AS total_stock
        FROM products GROUP BY category ORDER BY total_stock DESC;
    " > /dev/null
    psql -c "
        SELECT u.name, COUNT(DISTINCT o.id) AS orders, SUM(o.total)::numeric(10,2) AS revenue
        FROM users u
        JOIN orders o ON o.user_id = u.id
        WHERE o.status = 'delivered' AND o.created_at > NOW() - interval '7 days'
        GROUP BY u.name ORDER BY revenue DESC LIMIT 20;
    " > /dev/null
}

# Heavy analytical query — full joins across all tables, forces seq scans
workload_heavy_analytics() {
    psql -c "
        SELECT p.category,
               COUNT(DISTINCT o.id)                            AS total_orders,
               COUNT(DISTINCT o.user_id)                       AS unique_customers,
               SUM(oi.quantity * oi.unit_price)::numeric(12,2) AS revenue,
               AVG(oi.quantity * oi.unit_price)::numeric(10,2) AS avg_item_value,
               SUM(oi.quantity)                                AS units_sold,
               MAX(o.created_at)                              AS last_order_at
        FROM products p
        JOIN order_items oi ON oi.product_id = p.id
        JOIN orders o       ON o.id = oi.order_id
        JOIN users u        ON u.id = o.user_id
        GROUP BY p.category
        ORDER BY revenue DESC;
    " > /dev/null
}

# Slow customer report — no selective filter, large sort
workload_slow_report() {
    psql -c "
        SELECT u.id, u.name, u.status,
               COUNT(o.id)                              AS total_orders,
               COALESCE(SUM(o.total), 0)::numeric(12,2) AS lifetime_value,
               COALESCE(AVG(o.total), 0)::numeric(10,2) AS avg_order,
               MAX(o.created_at)                       AS last_order_date,
               COUNT(CASE WHEN o.status = 'cancelled' THEN 1 END) AS cancellations
        FROM users u
        LEFT JOIN orders o ON o.user_id = u.id
        GROUP BY u.id, u.name, u.status
        ORDER BY lifetime_value DESC
        LIMIT 100;
    " > /dev/null
}

# Idle in transaction — holds row locks via shell-level sleep, creating real
# "idle in transaction" state in pg_stat_activity while blocking other sessions
workload_idle_in_transaction() {
    local hold=$((3 + RANDOM % 6))
    {
        echo "BEGIN;"
        echo "SELECT id FROM products ORDER BY id LIMIT 30 FOR UPDATE;"
        sleep "$hold"
        echo "ROLLBACK;"
    } | command psql -U "$PGUSER" -d "$PGDB" -q > /dev/null 2>&1
}

# Blocked query — targets same rows as idle_in_transaction, will queue behind it
workload_blocked() {
    psql -c "
        BEGIN;
        UPDATE products
           SET stock = GREATEST(0, stock - (1 + (random()*3)::int))
         WHERE id IN (SELECT id FROM products ORDER BY id LIMIT 30);
        COMMIT;
    " > /dev/null
}

# Lock contention — grabs row locks on popular products and holds them briefly
workload_lock_contention() {
    psql -c "
        BEGIN;
        SELECT id FROM products
        ORDER BY id LIMIT 20
        FOR UPDATE;
        SELECT pg_sleep(0.3 + random() * 0.4);
        UPDATE products
           SET stock = GREATEST(0, stock - (1 + (random()*3)::int))
         WHERE id IN (SELECT id FROM products ORDER BY id LIMIT 20);
        COMMIT;
    " > /dev/null
}

# Competing status updates — multiple workers race to claim pending orders
workload_order_contention() {
    psql -c "
        BEGIN;
        SELECT id FROM orders
        WHERE status = 'pending'
        ORDER BY created_at
        LIMIT 10
        FOR UPDATE SKIP LOCKED;
        SELECT pg_sleep(0.2 + random() * 0.3);
        UPDATE orders SET status = 'processing', updated_at = NOW()
        WHERE id IN (
            SELECT id FROM orders WHERE status = 'pending'
            ORDER BY created_at LIMIT 10
            FOR UPDATE SKIP LOCKED
        );
        COMMIT;
    " > /dev/null
}

workload_user_churn() {
    psql -c "UPDATE users SET status = 'inactive', updated_at = NOW()
        WHERE id IN (SELECT id FROM users WHERE status='active' ORDER BY random() LIMIT 5);"
    psql -c "UPDATE users SET status = 'active', updated_at = NOW()
        WHERE id IN (SELECT id FROM users WHERE status='inactive' ORDER BY random() LIMIT 5);"
}

workload_restock() {
    psql -c "UPDATE products SET stock = stock + (50 + (random()*200)::int)
        WHERE id IN (SELECT id FROM products WHERE stock < 100 ORDER BY random() LIMIT 20);"
}

workload_cleanup() {
    psql -c "
        DELETE FROM order_items WHERE order_id IN (
            SELECT id FROM orders WHERE status='cancelled'
            AND created_at < NOW() - interval '15 minutes' LIMIT 10
        );"
    psql -c "
        DELETE FROM orders WHERE status='cancelled'
          AND created_at < NOW() - interval '15 minutes'
          AND id NOT IN (SELECT DISTINCT order_id FROM order_items)
          LIMIT 10;"
}

WORKLOADS=(
    workload_reads workload_reads workload_reads workload_reads
    workload_heavy_analytics workload_heavy_analytics
    workload_slow_report
    workload_new_order workload_new_order workload_new_order
    workload_process_orders workload_process_orders
    workload_idle_in_transaction workload_idle_in_transaction
    workload_blocked workload_blocked workload_blocked
    workload_lock_contention workload_lock_contention
    workload_order_contention workload_order_contention
    workload_cancel_orders
    workload_user_churn
    workload_restock
    workload_cleanup
)

run_worker() {
    local worker_id=$1
    local i=0
    while [ $SECONDS -lt $END ]; do
        fn="${WORKLOADS[$((RANDOM % ${#WORKLOADS[@]}))]}"
        $fn 2>/dev/null || true
        i=$((i + 1))
        if [ $((i % 100)) -eq 0 ]; then
            echo "[$(date -u +%H:%M:%S)] worker=$worker_id ops=$i remaining=$((END - SECONDS))s"
        fi
        sleep 0.05
    done
    echo "Worker $worker_id finished after $i ops."
}

echo "Starting $WORKERS workers for ${DURATION}s against db=${PGDB} user=${PGUSER}"
for w in $(seq 1 "$WORKERS"); do
    run_worker "$w" &
done
wait
echo "All workers finished."
