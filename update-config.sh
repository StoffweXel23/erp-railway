#!/bin/bash
cat > /home/frappe/frappe-bench/sites/localhost/site_config.json << EOF
{
    "db_host": "mariadb",
    "db_name": "${DB_NAME}",
    "db_password": "${DB_PASSWORD}",
    "db_type": "mariadb"
}
EOF 