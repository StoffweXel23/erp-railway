#!/bin/bash
set -e

# Logging-Funktion
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Debug: Zeige alle Umgebungsvariablen
log "Umgebungsvariablen:"
env | sort

# Setze Standardwerte für Hosts, falls nicht gesetzt
MYSQL_HOST=${DB_HOST:-mariadb}
MYSQL_PORT=${DB_PORT:-3306}
REDIS_CACHE_HOST=${REDIS_CACHE_HOST:-redis-cache}
REDIS_QUEUE_HOST=${REDIS_QUEUE_HOST:-redis-queue}
REDIS_SOCKETIO_HOST=${REDIS_SOCKETIO_HOST:-redis-socketio}

# Setze Datenbank-Credentials
MYSQL_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD}}
MYSQL_DATABASE=${MYSQL_DATABASE:-erpnext}
MYSQL_USER=${MYSQL_USER:-erpnext}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD}}

# Healthcheck: Warte auf MariaDB
log "Warte auf MariaDB ($MYSQL_HOST:$MYSQL_PORT)..."
/home/frappe/wait-for-it.sh "$MYSQL_HOST:$MYSQL_PORT" echo "MariaDB ist bereit."

# Healthcheck: Warte auf Redis-Cache
log "Warte auf Redis-Cache ($REDIS_CACHE_HOST:6379)..."
/home/frappe/wait-for-it.sh "$REDIS_CACHE_HOST:6379" echo "Redis-Cache ist bereit."

# Healthcheck: Warte auf Redis-Queue
log "Warte auf Redis-Queue ($REDIS_QUEUE_HOST:6379)..."
/home/frappe/wait-for-it.sh "$REDIS_QUEUE_HOST:6379" echo "Redis-Queue ist bereit."

# Healthcheck: Warte auf Redis-SocketIO
log "Warte auf Redis-SocketIO ($REDIS_SOCKETIO_HOST:6379)..."
/home/frappe/wait-for-it.sh "$REDIS_SOCKETIO_HOST:6379" echo "Redis-SocketIO ist bereit."

# Site anlegen, falls nicht vorhanden
if [ ! -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
  log "Lege neue Site $SITE_NAME an..."
  bench new-site "$SITE_NAME" \
    --mariadb-root-password "$MYSQL_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --db-name "$MYSQL_DATABASE" \
    --db-password "$MYSQL_PASSWORD" \
    --db-host "$MYSQL_HOST" \
    --db-port "$MYSQL_PORT" \
    --no-mariadb-socket \
    --install-app erpnext \
    --force

  # Build assets
  log "Baue Assets..."
  bench build
  bench clear-cache
  bench clear-website-cache
else
  log "Site $SITE_NAME existiert bereits."
fi

# Debug: Zeige Site-Status
log "Site-Status:"
bench --site "$SITE_NAME" show-config

# Production-Start
if [ "$PRODUCTION" = "1" ]; then
  log "Starte ERPNext mit gunicorn (Production-Modus)..."
  cd /home/frappe/frappe-bench
  exec /home/frappe/frappe-bench/env/bin/gunicorn -b 0.0.0.0:8000 frappe.app:application --log-level debug
else
  log "Starte ERPNext im Entwicklungsmodus (bench start)..."
  exec bench start
fi 