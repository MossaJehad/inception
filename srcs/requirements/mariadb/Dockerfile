FROM debian:12.15-slim
RUN apt-get update && apt-get install -y --no-install-recommends mariadb-server mariadb-client \
    && rm -rf /var/lib/apt/lists/* /var/lib/mysql/*
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/db-entrypoint
COPY tools/healthcheck.sh /usr/local/bin/db-healthcheck
RUN chmod 755 /usr/local/bin/db-entrypoint /usr/local/bin/db-healthcheck
EXPOSE 3306
ENTRYPOINT ["/usr/local/bin/db-entrypoint"]
CMD ["mariadbd", "--user=mysql", "--console"]
