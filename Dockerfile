# Multi-arch LibreSpeed build with non-root support (PSS restricted compatible)
# Source pulled from upstream at build time — no fork needed.
# Change LIBRESPEED_VERSION to upgrade.

FROM php:8-alpine AS source
RUN apk add --no-cache git
ARG LIBRESPEED_VERSION=5.5.1
RUN git clone --depth 1 --branch v${LIBRESPEED_VERSION} \
    https://github.com/librespeed/speedtest.git /src

FROM php:8-alpine

RUN apk add --quiet --no-cache \
    bash \
    apache2 \
    php-apache2 \
    php-ctype \
    php-phar \
    php-gd \
    php-openssl \
    php-pdo \
    php-pdo_mysql \
    php-pdo_pgsql \
    php-pdo_sqlite \
    php-pgsql \
    php-session \
    php-sqlite3

# Log to stdout/stderr
RUN ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log

# Copy upstream source from build stage
RUN mkdir -p /speedtest/results
COPY --from=source /src/backend/ /speedtest/backend/
COPY --from=source /src/results/ /speedtest/results/
COPY --from=source /src/*.js /speedtest/
COPY --from=source /src/favicon.ico /speedtest/
COPY --from=source /src/docker/servers.json /servers.json
COPY --from=source /src/docker/*.php /speedtest/

# Copy our modified entrypoint (non-root compatible)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Pre-configure Apache for non-root operation:
# - Set webroot to /var/www/html (Alpine default is /var/www/localhost/htdocs)
# - Set listen port to 8080 (unprivileged)
# - Make all runtime-writable dirs owned by apache user
RUN sed -i 's#"/var/www/localhost/htdocs"#"/var/www/html"#g' /etc/apache2/httpd.conf && \
    sed -i 's/^Listen 80$/Listen 8080/g' /etc/apache2/httpd.conf && \
    sed -i 's|ErrorLog .*|ErrorLog /dev/stderr|g' /etc/apache2/httpd.conf && \
    sed -i 's|CustomLog .* combined|CustomLog /dev/stdout combined|g' /etc/apache2/httpd.conf && \
    sed -i 's|TransferLog .*|TransferLog /dev/stdout|g' /etc/apache2/httpd.conf && \
    sed -i 's|^PidFile .*|PidFile /tmp/httpd.pid|g' /etc/apache2/conf.d/mpm.conf 2>/dev/null; \
    grep -q 'PidFile' /etc/apache2/httpd.conf && sed -i 's|^PidFile .*|PidFile /tmp/httpd.pid|g' /etc/apache2/httpd.conf || echo 'PidFile /tmp/httpd.pid' >> /etc/apache2/httpd.conf && \
    mkdir -p /var/www/html /run/apache2 /database && \
    chown -R apache:apache /var/www/html /run/apache2 /speedtest /database

ENV TITLE=LibreSpeed \
    MODE=standalone \
    PASSWORD=password \
    TELEMETRY=false \
    ENABLE_ID_OBFUSCATION=false \
    REDACT_IP_ADDRESSES=false \
    WEBPORT=8080

USER apache

STOPSIGNAL SIGWINCH

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${WEBPORT}/ || exit 1

LABEL org.opencontainers.image.title="LibreSpeed" \
      org.opencontainers.image.description="Multi-arch LibreSpeed with non-root support for PSS restricted Kubernetes" \
      org.opencontainers.image.source="https://github.com/antonioacg/librespeed" \
      org.opencontainers.image.licenses="LGPL-3.0-or-later"

EXPOSE 8080
WORKDIR /var/www/html
CMD ["bash", "/entrypoint.sh"]
