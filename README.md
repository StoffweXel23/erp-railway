# ERPNext + GPT-Assistant (Deploy to Railway)

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new/template/CMoD_X?referrer=gpt-assistant)

**Was passiert beim Deploy?**

1. Railway liest das `docker-compose.yml`.
2. Legt Services an:
   * `app` (Frappe Bench)
   * `mariadb`
   * 3× Redis
3. Bei jedem Start führt der Container aus:
   * `bench new-site` → Site anlegen
   * `bench get-app erpnext` → ERPNext installieren
   * `bench get-app gpt_assistant` → Custom-App installieren
   * OpenAI-Key setzen
   * `bench start`
