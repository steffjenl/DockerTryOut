FROM nginx:1.25.5-alpine
LABEL org.opencontainers.image.description="Cachet is a beautiful and powerful open source status page system." \
      org.opencontainers.image.authors="CachetHQ" \
      org.opencontainers.image.url="https://cachethq.io" \
      org.opencontainers.image.documentation="https://docs.cachethq.io" \
      org.opencontainers.image.source="https://github.com/cachethq/cachet"
EXPOSE 8000
CMD ["/sbin/entrypoint.sh"]

ARG cachet_ver
ARG archive_url

ENV cachet_ver ${cachet_ver:-3.x}
ENV archive_url ${archive_url:-https://github.com/cachethq/Cachet/archive/refs/heads/${cachet_ver}.tar.gz}
ENV COMPOSER_VERSION 2.7.6

RUN apk add --no-cache --update nano

RUN apk add --no-cache --update \
    nodejs \
    npm

RUN apk add --no-cache --update \
    mysql-client \
    php82 \
    php82-apcu \
    php82-bcmath \
    php82-ctype \
    php82-curl \
    php82-dom \
    php82-fileinfo \
    php82-fpm \
    php82-gd \
    php82-iconv \
    php82-intl \
    php82-json \
    php82-mbstring \
    php82-mysqlnd \
    php82-opcache \
    php82-openssl \
    php82-pdo \
    php82-pdo_mysql \
    php82-pdo_pgsql \
    php82-pdo_sqlite \
    php82-phar \
    php82-posix \
    php82-redis \
    php82-session \
    php82-simplexml \
    php82-soap \
    php82-sqlite3 \
    php82-tokenizer \
    php82-xml \
    php82-xmlwriter \
    php82-xmlreader \
    php82-zip \
    php82-zlib \
    postfix \
    postgresql \
    postgresql-client \
    sqlite \
    sudo \
    wget sqlite git curl bash grep \
    supervisor

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    ln -sf /dev/stdout /var/log/php82/error.log && \
    ln -sf /dev/stderr /var/log/php82/error.log

RUN adduser -S -s /bin/bash -u 1001 -G root www-data

RUN echo "www-data	ALL=(ALL:ALL)	NOPASSWD:SETENV:	/usr/sbin/postfix" >> /etc/sudoers

RUN touch /var/run/nginx.pid && \
    chown -R www-data:root /var/run/nginx.pid

RUN chown -R www-data:root /etc/php82/php-fpm.d

RUN mkdir -p /var/www/html && \
    mkdir -p /usr/share/nginx/cache && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /var/lib/nginx && \
    chown -R www-data:root /var/www /usr/share/nginx/cache /var/cache/nginx /var/lib/nginx/

# Install composer
RUN wget https://getcomposer.org/installer -O /tmp/composer-setup.php && \
    wget https://composer.github.io/installer.sig -O /tmp/composer-setup.sig && \
    php82 -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" && \
    php82 /tmp/composer-setup.php --version=$COMPOSER_VERSION --install-dir=bin && \
    php82 -r "unlink('/tmp/composer-setup.php');"

WORKDIR /var/www/html/
USER 1001

RUN wget ${archive_url} && \
    tar xzf ${cachet_ver}.tar.gz --strip-components=1 && \
    chown -R www-data:root /var/www/html && \
    rm -r ${cachet_ver}.tar.gz && \
    php82 /bin/composer.phar install -o && \
    rm -rf bootstrap/cache/*

COPY conf/php-fpm-pool.conf /etc/php82/php-fpm.d/www.conf
COPY conf/supervisord.conf /etc/supervisor/supervisord.conf
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx-site.conf /etc/nginx/conf.d/default.conf
COPY conf/.env.docker /var/www/html/.env
COPY entrypoint.sh /sbin/entrypoint.sh

USER root
RUN chmod g+rwx /var/run/nginx.pid && \
    chmod -R g+rw /var/www /usr/share/nginx/cache /var/cache/nginx /var/lib/nginx/ /etc/php82/php-fpm.d storage
USER 1001
