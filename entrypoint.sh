#!/bin/bash
set -e

# Signal-Handler für sauberes Beenden
cleanup() {
  log "Container wird beendet..."
  if [ -n "$GUNICORN_PID" ]; then
    log "Beende Gunicorn-Prozess..."
    kill -TERM "$GUNICORN_PID" 2>/dev/null || true
  fi
  exit 0
}

# Trap für Signale
trap cleanup SIGTERM SIGINT

# Logging-Funktion
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Konfigurationsvalidierung
validate_config() {
  log "Validiere Konfiguration..."
  
  # Prüfe erforderliche Umgebungsvariablen
  local required_vars=("SITE_NAME" "ADMIN_PASSWORD" "MYSQLHOST" "MYSQLPORT" "MYSQLUSER" "MYSQLPASSWORD" "MYSQLDATABASE" "RAILWAY_REDIS_URL")
  for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
      log "FEHLER: Umgebungsvariable $var ist nicht gesetzt"
      exit 1
    fi
  done
  
  # Prüfe Port
  if [ -z "${PORT}" ]; then
    log "WARNUNG: PORT nicht gesetzt, verwende Standardport 8000"
    export PORT=8000
  fi
  
  log "Konfiguration ist gültig"
}

# Debug: Zeige alle Umgebungsvariablen
log "Umgebungsvariablen:"
env | sort

# Validiere Konfiguration
validate_config

# MySQL-Verbindung testen
log "Teste MySQL-Verbindung..."
until mysql -h"${MYSQLHOST}" -P"${MYSQLPORT}" -u"${MYSQLUSER}" -p"${MYSQLPASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
  log "Warte auf MySQL-Verfügbarkeit..."
  sleep 2
done
log "MySQL-Verbindung erfolgreich hergestellt"

# Site anlegen oder aktualisieren
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
else
  log "Site $SITE_NAME existiert bereits."
fi

# Konfiguriere Site-Einstellungen
log "Konfiguriere Site-Einstellungen..."
bench --site "$SITE_NAME" set-config redis_cache "${RAILWAY_REDIS_URL}"
bench --site "$SITE_NAME" set-config redis_queue "${RAILWAY_REDIS_URL}"
bench --site "$SITE_NAME" set-config redis_socketio "${RAILWAY_REDIS_URL}"
bench --site "$SITE_NAME" set-config webserver_port "${PORT}"

# Build assets nur für neue Sites
if [ ! -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
  log "Baue Assets..."
  bench build
  bench clear-cache
  bench clear-website-cache
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
import multiprocessing
import os

# Server Socket
bind = "0.0.0.0:${PORT}"
backlog = 2048

# Worker Processes
workers = 1
worker_class = "sync"
worker_connections = 1000
timeout = 120
keepalive = 2
max_requests = 0
max_requests_jitter = 0
graceful_timeout = 30

# Server Mechanics
daemon = False
pidfile = None
umask = 0
user = 1000
group = 1000
tmp_upload_dir = None

# Logging
accesslog = "-"
errorlog = "-"
loglevel = "debug"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'

# Process Naming
proc_name = None

# Server Hooks
def on_starting(server):
    pass

def on_reload(server):
    pass

def when_ready(server):
    pass

def post_fork(server, worker):
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def pre_fork(server, worker):
    pass

def pre_exec(server):
    server.log.info("Forked child, re-executing.")

def worker_int(worker):
    worker.log.info("worker received INT or QUIT signal")

def worker_abort(worker):
    worker.log.info("worker received SIGABRT signal")

def worker_exit(server, worker):
    server.log.info("Worker exited (pid: %s)", worker.pid)
EOF

  # Starte Gunicorn im Hintergrund und speichere PID
  /home/frappe/frappe-bench/env/bin/gunicorn -c gunicorn.conf.py frappe.app:application &
  GUNICORN_PID=$!

  # Warte auf Gunicorn-Prozess
  wait $GUNICORN_PID
else
  log "Starte ERPNext im Entwicklungsmodus (bench start)..."
  exec bench start
fi 