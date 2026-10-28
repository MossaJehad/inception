FROM debian:12.15-slim
RUN apt-get update && apt-get install -y --no-install-recommends busybox \
    && rm -rf /var/lib/apt/lists/*
COPY conf/httpd.conf /etc/static-site.conf
COPY site/ /srv/site/
USER www-data
EXPOSE 8080
CMD ["busybox", "httpd", "-f", "-p", "8080", "-h", "/srv/site", "-c", "/etc/static-site.conf"]
