#!/bin/bash
set -e

# Logging-Funktion
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Healthcheck: Warte auf MariaDB
log "Warte auf MariaDB ($DB_HOST:$DB_PORT)..."
/home/frappe/wait-for-it.sh $DB_HOST:$DB_PORT -t 120 --strict -- echo "MariaDB ist bereit."

# Healthcheck: Warte auf Redis-Cache
log "Warte auf Redis-Cache ($REDIS_CACHE)..."
/home/frappe/wait-for-it.sh $(echo $REDIS_CACHE | sed 's/:/ /') -t 60 --strict -- echo "Redis-Cache ist bereit."

# Healthcheck: Warte auf Redis-Queue
log "Warte auf Redis-Queue ($REDIS_QUEUE)..."
/home/frappe/wait-for-it.sh $(echo $REDIS_QUEUE | sed 's/:/ /') -t 60 --strict -- echo "Redis-Queue ist bereit."

# Healthcheck: Warte auf Redis-SocketIO
log "Warte auf Redis-SocketIO ($REDIS_SOCKETIO)..."
/home/frappe/wait-for-it.sh $(echo $REDIS_SOCKETIO | sed 's/:/ /') -t 60 --strict -- echo "Redis-SocketIO ist bereit."

# Site anlegen, falls nicht vorhanden
if [ ! -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
  log "Lege neue Site $SITE_NAME an..."
  bench new-site $SITE_NAME --mariadb-root-password $MYSQL_ROOT_PASSWORD --admin-password $ADMIN_PASSWORD --db-name $DB_NAME --db-password $DB_PASSWORD --no-mariadb-socket --install-app erpnext --force
else
  log "Site $SITE_NAME existiert bereits."
fi

# Production-Start
if [ "$PRODUCTION" = "1" ]; then
  log "Starte ERPNext mit gunicorn (Production-Modus)..."
  exec gunicorn -b 0.0.0.0:8000 frappe.app:application
else
  log "Starte ERPNext im Entwicklungsmodus (bench start)..."
  exec bench start
fi 