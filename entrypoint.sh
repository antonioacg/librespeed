#!/bin/bash
# Non-root entrypoint for LibreSpeed
# Apache config and file ownership pre-set at build time — no root needed.
set -e

# Cleanup previous run
rm -rf /var/www/html/*

# Copy frontend files
cp /speedtest/*.js /var/www/html/
cp /speedtest/favicon.ico /var/www/html/

# Set up backend for standalone/dual modes
if [[ "$MODE" == "standalone" || "$MODE" == "dual" ]]; then
  cp -r /speedtest/backend/ /var/www/html/backend
  if [ -n "$IPINFO_APIKEY" ]; then
    sed -i "s/\$IPINFO_APIKEY = ''/\$IPINFO_APIKEY = '$IPINFO_APIKEY'/g" /var/www/html/backend/getIP_ipInfo_apikey.php
  fi
fi

if [ "$MODE" == "backend" ]; then
  cp -r /speedtest/backend/* /var/www/html
  if [ -n "$IPINFO_APIKEY" ]; then
    sed -i "s/\$IPINFO_APIKEY = ''/\$IPINFO_APIKEY = '$IPINFO_APIKEY'/g" /var/www/html/getIP_ipInfo_apikey.php
  fi
fi

# Set up index page
if [ "$MODE" != "backend" ]; then
  cp /speedtest/ui.php /var/www/html/index.php
fi

# Apply telemetry settings
if [[ "$TELEMETRY" == "true" && ("$MODE" == "frontend" || "$MODE" == "standalone" || "$MODE" == "dual") ]]; then
  cp -r /speedtest/results /var/www/html/results

  if [ "$MODE" == "frontend" ]; then
    mkdir -p /var/www/html/backend
    cp /speedtest/backend/getIP_util.php /var/www/html/backend
  fi

  if [ "$DB_TYPE" == "mysql" ]; then
    sed -i "s/\$db_type = '.*'/\$db_type = '$DB_TYPE'/g" /var/www/html/results/telemetry_settings.php
    sed -i "s/\$MySql_username = '.*'/\$MySql_username = '$DB_USERNAME'/g" /var/www/html/results/telemetry_settings.php
    sed -i "s/\$MySql_password = '.*'/\$MySql_password = '$DB_PASSWORD'/g" /var/www/html/results/telemetry_settings.php
    sed -i "s/\$MySql_hostname = '.*'/\$MySql_hostname = '$DB_HOSTNAME'/g" /var/www/html/results/telemetry_settings.php
    sed -i "s/\$MySql_databasename = '.*'/\$MySql_databasename = '$DB_NAME'/g" /var/www/html/results/telemetry_settings.php
    if [ -n "$DB_PORT" ]; then
      sed -i "s/\$MySql_port = '.*'/\$MySql_port = '$DB_PORT'/g" /var/www/html/results/telemetry_settings.php
    fi
  elif [ "$DB_TYPE" == "postgresql" ]; then
    sed -i "s/\$db_type = '.*'/\$db_type = '$DB_TYPE'/g" /var/www/html/results/telemetry_settings.php
    sed -i "s/\$PostgreSql_username = '.*'/\$PostgreSql_username = '$DB_USERNAME'/g" /var/www/html/results/telemetry_settings.php
    sed -i "s/\$PostgreSql_password = '.*'/\$PostgreSql_password = '$DB_PASSWORD'/g" /var/www/html/results/telemetry_settings.php
    sed -i "s/\$PostgreSql_hostname = '.*'/\$PostgreSql_hostname = '$DB_HOSTNAME'/g" /var/www/html/results/telemetry_settings.php
    sed -i "s/\$PostgreSql_databasename = '.*'/\$PostgreSql_databasename = '$DB_NAME'/g" /var/www/html/results/telemetry_settings.php
  else
    sed -i "s/\$db_type = '.*'/\$db_type = 'sqlite'/g" /var/www/html/results/telemetry_settings.php
  fi

  sed -i "s|\$Sqlite_db_file = .*'|\$Sqlite_db_file='/database/db.sql'|g" /var/www/html/results/telemetry_settings.php
  sed -i "s/\$stats_password = '.*'/\$stats_password = '$PASSWORD'/g" /var/www/html/results/telemetry_settings.php

  if [ "$ENABLE_ID_OBFUSCATION" == "true" ]; then
    sed -i "s/\$enable_id_obfuscation = .*;/\$enable_id_obfuscation = true;/g" /var/www/html/results/telemetry_settings.php
    if [ -n "$OBFUSCATION_SALT" ]; then
      if [[ "$OBFUSCATION_SALT" =~ ^0x[0-9a-fA-F]+$ ]]; then
        echo "<?php" > /var/www/html/results/idObfuscation_salt.php
        echo "\$OBFUSCATION_SALT = $OBFUSCATION_SALT;" >> /var/www/html/results/idObfuscation_salt.php
      else
        echo "WARNING: Invalid OBFUSCATION_SALT format." >&2
      fi
    fi
  fi

  if [ "$REDACT_IP_ADDRESSES" == "true" ]; then
    sed -i "s/\$redact_ip_addresses = .*;/\$redact_ip_addresses = true;/g" /var/www/html/results/telemetry_settings.php
  fi
fi

echo "Starting Apache on port ${WEBPORT}"
exec httpd -DFOREGROUND
