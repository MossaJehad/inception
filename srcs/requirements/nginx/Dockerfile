FROM debian:12.15-slim
RUN apt-get update && apt-get install -y --no-install-recommends nginx openssl gettext-base curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default \
    && sed -i '/^fastcgi_param[[:space:]]*HTTP_HOST[[:space:]]/d; /^fastcgi_param[[:space:]]*SERVER_PORT[[:space:]]/d' /etc/nginx/fastcgi_params
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/site.conf.template /etc/nginx/templates/site.conf.template
COPY tools/entrypoint.sh /usr/local/bin/nginx-entrypoint
RUN chmod 755 /usr/local/bin/nginx-entrypoint
EXPOSE 443
ENTRYPOINT ["/usr/local/bin/nginx-entrypoint"]
CMD ["nginx", "-g", "daemon off;"]
