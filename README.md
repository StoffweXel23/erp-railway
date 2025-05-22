# Railway Deployment für ERPNext/Frappe

Dieses Verzeichnis enthält alle nötigen Dateien, um dein ERPNext/Frappe-Projekt production-ready auf Railway zu deployen.

## Enthaltene Dateien
- `Dockerfile`: Production-Setup, startet gunicorn als WSGI-Server
- `docker-compose.yml`: Alle Services (mariadb, redis, app), Healthchecks, Railway-tauglich
- `entrypoint.sh`: Healthchecks, automatisches Site-Setup, Production-Start
- `wait-for-it.sh`: Service-Warte-Skript
- `create-site.ps1`/`update-config.sh`: Optional für Site-Setup und Konfig-Updates

## Wichtige Umgebungsvariablen (im Railway Dashboard setzen)
- `MYSQL_ROOT_PASSWORD`: Root-Passwort für MariaDB
- `MYSQL_DATABASE`: Name der ERPNext-Datenbank
- `MYSQL_USER`: Datenbank-Benutzer
- `MYSQL_PASSWORD`: Datenbank-Passwort
- `SITE_NAME`: Name der Frappe/ERPNext-Site (z.B. "localhost" oder dein Domainname)
- `ADMIN_PASSWORD`: Passwort für den Administrator-Login

## Deployment-Ablauf
1. Repository (mit diesem Ordner) zu Railway pushen
2. Im Railway-Dashboard ein neues Projekt anlegen und die `docker-compose.yml` als Einstiegspunkt wählen
3. Alle oben genannten Umgebungsvariablen im Railway-Dashboard setzen
4. Railway baut und startet alle Container automatisch
5. Nach dem ersten Start ist ERPNext unter `https://<dein-railway-projekt>.up.railway.app` erreichbar

## Hinweise
- **Production-Server:** Es wird gunicorn als WSGI-Server verwendet (kein Entwicklungsserver!)
- **Backups:** Mache regelmäßig Backups deiner Datenbank und Sites (z.B. mit `bench backup`)
- **Datenbank-Import:** Um eine bestehende Datenbank zu übernehmen, importiere dein Backup in die Railway-MariaDB
- **Keine Passwörter im Code:** Alle sensiblen Daten werden über Railway-ENV-Variablen gesteuert

## Support
Bei Problemen kopiere relevante Logausgaben und poste sie im Chat – so kann gezielt geholfen werden!
