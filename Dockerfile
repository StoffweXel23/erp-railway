FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    redis-tools \
    mariadb-client \
    netcat-traditional \
    nodejs \
    npm \
    cron \
    dnsutils \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g yarn

# Create frappe user
RUN useradd -ms /bin/bash frappe

# Set working directory
WORKDIR /home/frappe

# Copy scripts
COPY --chown=frappe:frappe wait-for-it.sh /home/frappe/
COPY --chown=frappe:frappe entrypoint.sh /home/frappe/
RUN chmod +x /home/frappe/wait-for-it.sh /home/frappe/entrypoint.sh

# Switch to frappe user
USER frappe
# Set PATH so that bench is found
ENV PATH="/home/frappe/.local/bin:$PATH"

# Install frappe-bench
RUN pip install --user frappe-bench

# Initialize frappe-bench
RUN bench init frappe-bench --frappe-branch version-15 --skip-assets --skip-redis-config-generation \
    && /home/frappe/frappe-bench/env/bin/pip install "redis>=4.5.5" \
    && cd /home/frappe/frappe-bench && bench get-app erpnext --branch version-15 --skip-assets https://github.com/frappe/erpnext \
    && /home/frappe/frappe-bench/env/bin/pip install "redis>=4.5.5"

# Update browserslist database
RUN cd /home/frappe/frappe-bench/apps/frappe && \
    npm install update-browserslist-db && \
    npx update-browserslist-db

# Set working directory
WORKDIR /home/frappe/frappe-bench

# Production: Starte mit gunicorn
CMD ["gunicorn", "-b", "0.0.0.0:8000", "frappe.app:application"]



