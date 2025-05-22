#!/bin/bash

# Aktiviere Debug-Modus nur für bestimmte Bereiche
debug() {
  echo "[DEBUG] $1" >&2
}

# Logging-Funktion
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Sichere Umgebungsvariablen-Anzeige
log_env() {
  log "Umgebungsvariablen:"
  # Sortiere und filtere sensible Daten
  env | sort | while IFS='=' read -r key value; do
    case "$key" in
      *PASSWORD*|*SECRET*|*KEY*|*TOKEN*|*AUTH*|*MYSQL_URL*)
        log "$key=*****"
        ;;
      *)
        log "$key=$value"
        ;;
    esac
  done
}

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

# Debug: Zeige Umgebungsvariablen (maskiert)
log_env

# Konfigurationsvalidierung
validate_config() {
  log "Validiere Konfiguration..."
  
  # Prüfe erforderliche Umgebungsvariablen
  local required_vars=("SITE_NAME" "ADMIN_PASSWORD" "MYSQLHOST" "MYSQLPORT" "MYSQLUSER" "MYSQLPASSWORD" "MYSQLDATABASE" "RAILWAY_REDIS_URL")
  for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
      log "FEHLER: Umgebungsvariable $var ist nicht gesetzt"
      return 1
    fi
  done
  
  # Prüfe Port
  if [ -z "${PORT}" ]; then
    log "WARNUNG: PORT nicht gesetzt, verwende Standardport 8000"
    export PORT=8000
  fi
  
  log "Konfiguration ist gültig"
  return 0
}

# Validiere Konfiguration
if ! validate_config; then
  log "FEHLER: Konfigurationsvalidierung fehlgeschlagen"
  exit 1
fi

# MySQL-Verbindung testen
log "Teste MySQL-Verbindung..."
max_retries=30
retry_count=0
while ! mysql -h"${MYSQLHOST}" -P"${MYSQLPORT}" -u"${MYSQLUSER}" -p"${MYSQLPASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
  retry_count=$((retry_count + 1))
  if [ $retry_count -ge $max_retries ]; then
    log "FEHLER: MySQL-Verbindung konnte nicht hergestellt werden nach $max_retries Versuchen"
    exit 1
  fi
  log "Warte auf MySQL-Verfügbarkeit... (Versuch $retry_count/$max_retries)"
  sleep 2
done
log "MySQL-Verbindung erfolgreich hergestellt"

# Site anlegen oder aktualisieren
if [ ! -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
  log "Lege neue Site $SITE_NAME an..."
  if ! bench new-site "$SITE_NAME" \
    --admin-password "${ADMIN_PASSWORD}" \
    --db-name "${MYSQLDATABASE}" \
    --db-password "${MYSQLPASSWORD}" \
    --db-host "${MYSQLHOST}" \
    --db-port "${MYSQLPORT}" \
    --db-type mariadb \
    --install-app erpnext \
    --force 2>&1 | tee /tmp/site_creation.log; then
    log "FEHLER: Site-Erstellung fehlgeschlagen. Log:"
    cat /tmp/site_creation.log
    exit 1
  fi
else
  log "Site $SITE_NAME existiert bereits."
fi

# Konfiguriere Site-Einstellungen
log "Konfiguriere Site-Einstellungen..."
for config in redis_cache redis_queue redis_socketio webserver_port; do
  value=""
  case $config in
    redis_cache|redis_queue|redis_socketio)
      value="${RAILWAY_REDIS_URL}"
      ;;
    webserver_port)
      value="${PORT}"
      ;;
  esac
  
  if ! bench --site "$SITE_NAME" set-config "$config" "$value" 2>&1 | tee -a /tmp/site_config.log; then
    log "FEHLER: Konfiguration von $config fehlgeschlagen. Log:"
    cat /tmp/site_config.log
    exit 1
  fi
done

# Build assets nur für neue Sites
if [ ! -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
  log "Baue Assets..."
  if ! bench build 2>&1 | tee /tmp/build.log; then
    log "FEHLER: Asset-Build fehlgeschlagen. Log:"
    cat /tmp/build.log
    exit 1
  fi
  bench clear-cache
  bench clear-website-cache
fi

# Debug: Zeige Site-Status (maskiert)
log "Site-Status:"
bench --site "$SITE_NAME" show-config | while IFS='|' read -r key value; do
  case "$key" in
    *password*|*secret*|*key*|*token*|*auth*)
      log "$key|*****"
      ;;
    *)
      log "$key|$value"
      ;;
  esac
done

# Production-Start
if [ "$PRODUCTION" = "1" ]; then
  log "Starte ERPNext mit gunicorn (Production-Modus) auf Port ${PORT}..."
  cd /home/frappe/frappe-bench || {
    log "FEHLER: Konnte nicht in /home/frappe/frappe-bench wechseln"
    exit 1
  }
  
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
  /home/frappe/frappe-bench/env/bin/gunicorn -c gunicorn.conf.py frappe.app:application 2>&1 | tee /tmp/gunicorn.log &
  GUNICORN_PID=$!

  # Warte auf Gunicorn-Prozess
  wait $GUNICORN_PID
  GUNICORN_EXIT_CODE=$?
  
  if [ $GUNICORN_EXIT_CODE -ne 0 ]; then
    log "FEHLER: Gunicorn beendet mit Code $GUNICORN_EXIT_CODE. Log:"
    cat /tmp/gunicorn.log
    exit 1
  fi
else
  log "Starte ERPNext im Entwicklungsmodus (bench start)..."
  exec bench start
fi 