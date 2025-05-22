#!/bin/bash
#   Use this script to test if a given TCP host/port are available
#   Source: https://github.com/vishnubob/wait-for-it

set -e

host="$1"
shift
cmd="$@"

# Set default timeout to 60 seconds
timeout=60
start_time=$(date +%s)

# Extract host and port
hostname="${host%:*}"
port="${host#*:}"

until {
    if [[ "$hostname" == "$MYSQLHOST" ]]; then
        # Check MySQL connection using Railway credentials
        mysql -h "$MYSQLHOST" -P "$MYSQLPORT" -u "$MYSQLUSER" -p"$MYSQLPASSWORD" -e "SELECT 1" >/dev/null 2>&1
    else
        # Check Redis connection
        redis-cli -h "$hostname" -p "$port" ping >/dev/null 2>&1
    fi
} || [ $? -eq 1 ]; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $timeout ]; then
        >&2 echo "Timeout after ${timeout}s waiting for $host"
        exit 1
    fi
    
    >&2 echo "Waiting for $host to be ready... (${elapsed}s)"
    sleep 2
done

>&2 echo "$host is ready!"
if [ ! -z "$cmd" ]; then
    $cmd
fi 