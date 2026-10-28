FROM debian:12.15-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libfcgi-bin php8.2-fpm php8.2-cli php8.2-mysql \
    php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-intl \
    && rm -rf /var/lib/apt/lists/*
# Pin upstream source releases and verify their SHA-256 checksums before execution.
RUN curl -fsSL --retry 3 https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar -o /usr/local/bin/wp \
    && echo 'ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c  /usr/local/bin/wp' | sha256sum -c - \
    && chmod 755 /usr/local/bin/wp \
    && curl -fsSL --retry 3 https://wordpress.org/wordpress-7.1.3.tar.gz -o /tmp/wordpress.tar.gz \
    && echo 'd2a09acb6a15e3b9c471d72557753c266d6f41a79ed19bfe04cbfe49e283b2a5  /tmp/wordpress.tar.gz' | sha256sum -c - \
    && tar -xzf /tmp/wordpress.tar.gz -C /usr/src \
    && rm /tmp/wordpress.tar.gz
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY conf/wp-config.php /etc/wordpress/wp-config.php
COPY tools/entrypoint.sh /usr/local/bin/wp-entrypoint
COPY tools/healthcheck.sh /usr/local/bin/wp-healthcheck
COPY tools/bootstrap.php /usr/local/lib/wp-bootstrap.php
RUN mkdir -p /run/php /var/www/html \
    && chmod 755 /usr/local/bin/wp-entrypoint /usr/local/bin/wp-healthcheck \
    && sed -i 's|^error_log =.*|error_log = /proc/self/fd/2|' /etc/php/8.2/fpm/php-fpm.conf
WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/wp-entrypoint"]
CMD ["php-fpm8.2", "--nodaemonize"]
