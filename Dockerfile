FROM alpine:edge

RUN printf "https://dl-cdn.alpinelinux.org/alpine/edge/main\nhttps://dl-cdn.alpinelinux.org/alpine/edge/community\nhttps://dl-cdn.alpinelinux.org/alpine/edge/testing\n" > /etc/apk/repositories

# update apk repositories & upgrade all
RUN apk update && apk upgrade

ARG UID=1001
ARG GID=1001

RUN  set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup -g $GID -S nginx \
    && adduser -S -D -H -u $UID -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apk --no-cache add \
        ca-certificates \
        gettext \
        bash \
        curl \
        rsync \
        sudo \
        git \
        icu-data-full \
        libmcrypt \
        nginx \
        supervisor \
        shadow \
        unzip \
        patch \
        nodejs \
        npm \
        php85 \
        php85-bcmath \
        php85-common \
        php85-ctype \
        php85-curl \
        php85-dom \
        php85-fileinfo \
        php85-fpm \
        php85-ftp \
        php85-gd \
        php85-iconv \
        php85-intl \
        php85-mbstring \
        php85-mysqlnd \
        php85-openssl \
        php85-pcntl \
        php85-pdo \
        php85-pdo_mysql \
        php85-pecl-apcu \
        php85-pecl-lzf \
        php85-pecl-redis \
        php85-pecl-zstd \
        php85-phar \
        php85-posix \
        php85-session \
        php85-simplexml \
        php85-soap \
        php85-sodium \
        php85-sockets \
        php85-tokenizer \
        php85-xml \
        php85-xmlreader \
        php85-xmlwriter \
        php85-xsl \
        php85-zip \
    && sed -i '/Include files with config snippets into the root context/,+1d' /etc/nginx/nginx.conf \
    && sed -ie "s#include /etc/nginx/http.d/#include /etc/nginx/conf.d/#g" /etc/nginx/nginx.conf \
    && mkdir /var/www/html && chown nginx:nginx /var/www/html \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Add v8js
RUN apk add --no-cache nodejs-dev php85-dev alpine-sdk
RUN mkdir /usr/local/include && cp -rs /usr/include/node/* /usr/local/include/
WORKDIR /tmp
RUN git clone https://github.com/phpv8/v8js.git --branch php8
WORKDIR /tmp/v8js
RUN phpize && ./configure && make && make test \
    && cp -v modules/v8js.* `php -r "echo ini_get('extension_dir');"` \
    && rm -rf /tmp/v8js
COPY conf/00_v8js.ini /etc/php85/conf.d/00_v8js.ini
RUN php --ri v8js

COPY conf/www.conf /etc/php85/php-fpm.d/www.conf
COPY conf/default.conf conf/healthz.conf /etc/nginx/conf.d/
COPY healthz /var/www/healthz
COPY bin/setup.sh /setup.sh
COPY bin/run.sh /run.sh
COPY conf/supervisord.conf /etc/supervisord.conf
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

EXPOSE 80

WORKDIR /var/www/html

CMD ["/run.sh"]
