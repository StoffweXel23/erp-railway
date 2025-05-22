#!/bin/bash

# Export environment variables for wait-for-it.sh
export MARIADB_ROOT_PASSWORD

# Function to check if services are ready
check_services() {
    # Wait for MariaDB
    echo "Waiting for MariaDB..."
    /home/frappe/wait-for-it.sh mariadb:3306

    # Additional wait to ensure MariaDB is fully ready
    echo "Ensuring MariaDB is fully ready..."
    sleep 15

    # Wait for Redis services
    echo "Waiting for Redis services..."
    /home/frappe/wait-for-it.sh redis-cache:6379
    /home/frappe/wait-for-it.sh redis-queue:6379
    /home/frappe/wait-for-it.sh redis-socketio:6379

    # Configure Redis settings
    echo "Configuring Redis settings..."
    bench set-config -g redis_cache "redis://${REDIS_CACHE_HOST}:6379"
    bench set-config -g redis_queue "redis://${REDIS_QUEUE_HOST}:6379"
    bench set-config -g redis_socketio "redis://${REDIS_SOCKETIO_HOST}:6379"
}

# Create new site if it doesn't exist
if [ ! -f "/home/frappe/frappe-bench/sites/${SITE_NAME}/site_config.json" ]; then
    echo "Creating new site..."
    check_services
    bench new-site ${SITE_NAME} \
        --mariadb-root-password ${MARIADB_ROOT_PASSWORD} \
        --admin-password ${ADMIN_PASSWORD} \
        --install-app erpnext \
        --db-host mariadb \
        --db-port 3306

    # Set as default site
    bench use ${SITE_NAME}

    # Configure database settings
    echo "Configuring database settings..."
    bench set-config -g db_host mariadb
    bench set-config -g db_port 3306
    bench set-config -g db_name ${DB_NAME}
    bench set-config -g db_user ${DB_USER}
    bench set-config -g db_password ${DB_PASSWORD}
fi

# If starting bench, ensure services are ready
if [ "$1" = "bench" ] && [ "$2" = "start" ]; then
    check_services
    echo "Starting Frappe bench..."
    exec bench start
else
    exec "$@"
fi 