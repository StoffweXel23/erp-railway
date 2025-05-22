#!/bin/bash
set -e

# Logging-Funktion
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Debug: Zeige alle Umgebungsvariablen
log "Umgebungsvariablen:"
env | sort

# Port-Validierung
if [ -z "${PORT}" ]; then
  log "WARNUNG: PORT nicht gesetzt, verwende Standardport 8000"
  export PORT=8000
fi

# MySQL-Verbindung testen
log "Teste MySQL-Verbindung..."
until mysql -h"${MYSQLHOST}" -P"${MYSQLPORT}" -u"${MYSQLUSER}" -p"${MYSQLPASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
  log "Warte auf MySQL-Verfügbarkeit..."
  sleep 2
done
log "MySQL-Verbindung erfolgreich hergestellt"

# Site anlegen, falls nicht vorhanden
if [ ! -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
  log "Lege neue Site $SITE_NAME an..."
  bench new-site "$SITE_NAME" \
    --admin-password "${ADMIN_PASSWORD}" \
    --db-name "${MYSQLDATABASE}" \
    --db-password "${MYSQLPASSWORD}" \
    --db-host "${MYSQLHOST}" \
    --db-port "${MYSQLPORT}" \
    --db-type mariadb \
    --install-app erpnext \
    --force

  # Konfiguriere Redis-Einstellungen
  log "Konfiguriere Redis-Einstellungen..."
  bench --site "$SITE_NAME" set-config redis_cache "${RAILWAY_REDIS_URL}"
  bench --site "$SITE_NAME" set-config redis_queue "${RAILWAY_REDIS_URL}"
  bench --site "$SITE_NAME" set-config redis_socketio "${RAILWAY_REDIS_URL}"

  # Setze den Webserver-Port
  log "Setze Webserver-Port auf ${PORT}..."
  bench --site "$SITE_NAME" set-config webserver_port "${PORT}"

  # Build assets
  log "Baue Assets..."
  bench build
  bench clear-cache
  bench clear-website-cache
else
  log "Site $SITE_NAME existiert bereits."
  
  # Aktualisiere Redis-Einstellungen
  log "Aktualisiere Redis-Einstellungen..."
  bench --site "$SITE_NAME" set-config redis_cache "${RAILWAY_REDIS_URL}"
  bench --site "$SITE_NAME" set-config redis_queue "${RAILWAY_REDIS_URL}"
  bench --site "$SITE_NAME" set-config redis_socketio "${RAILWAY_REDIS_URL}"
  
  # Aktualisiere den Webserver-Port
  log "Aktualisiere Webserver-Port auf ${PORT}..."
  bench --site "$SITE_NAME" set-config webserver_port "${PORT}"
fi

# Debug: Zeige Site-Status
log "Site-Status:"
bench --site "$SITE_NAME" show-config

# Production-Start
if [ "$PRODUCTION" = "1" ]; then
  log "Starte ERPNext mit gunicorn (Production-Modus) auf Port ${PORT}..."
  cd /home/frappe/frappe-bench
  
  # Erstelle gunicorn.conf.py
  cat > gunicorn.conf.py << EOF
bind = "0.0.0.0:${PORT}"
workers = 1
worker_class = "sync"
timeout = 120
keepalive = 2
max_requests = 0
max_requests_jitter = 0
graceful_timeout = 30
EOF

  exec /home/frappe/frappe-bench/env/bin/gunicorn -c gunicorn.conf.py frappe.app:application --log-level debug
else
  log "Starte ERPNext im Entwicklungsmodus (bench start)..."
  exec bench start
fi 