FROM php:7.3-fpm-alpine

RUN apk add --update --no-cache mariadb-client libbz2 git zlib pcre nodejs \
    yarn optipng libtool nasm openssh-client libxslt libzip icu libpng bzip2

# Chromium dependencies
RUN echo @edge http://nl.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories \
    && echo @edge http://nl.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories \
    && apk update \
    && apk add --no-cache \
    chromium@edge \
    harfbuzz@edge \
    nss@edge

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD 1

# "fake" dbus address to prevent errors
# https://github.com/SeleniumHQ/docker-selenium/issues/87
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

# Build dependencies
RUN apk add --no-cache --virtual build-dependencies autoconf automake build-base libzip-dev libxslt-dev icu-dev \
    libpng-dev bzip2-dev

RUN pecl install apcu \
    && pecl install xdebug-2.7.1 \
    && docker-php-ext-enable apcu xdebug

RUN pecl install -o -f redis \
  &&  rm -rf /tmp/pear \
  &&  docker-php-ext-enable redis

RUN docker-php-ext-configure zip --with-libzip
RUN docker-php-ext-install exif fileinfo gd intl mbstring pdo_mysql opcache sockets zip xsl

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && chmod +x /usr/bin/composer

RUN echo "date.timezone = Europe/Stockholm" >> /usr/local/etc/php/php.ini \
    && echo "opcache.enable = 1" >> /usr/local/etc/php/php.ini \
    && echo "opcache.enable_cli = 1" >> /usr/local/etc/php/php.ini \
    && echo "opcache.memory_consumption = 256" >> /usr/local/etc/php/php.ini \
    && echo "opcache.max_accelerated_files = 100000" >> /usr/local/etc/php/php.ini \
    && echo "opcache.interned_strings_buffer = 16" >> /usr/local/etc/php/php.ini \
    && echo "realpath_cache_size = 50M" >> /usr/local/etc/php/php.ini \
    && echo "apc.entries_hint = 256000" >> /usr/local/etc/php/php.ini \
    && echo "apc.shm_size = 512M" >> /usr/local/etc/php/php.ini \
    && echo "apc.enabled = 1" >> /usr/local/etc/php/php.ini \
    && echo "apc.enable_cli = 1" >> /usr/local/etc/php/php.ini \
    && echo /usr/local/etc/php/php.ini

RUN git clone git://github.com/mozilla/mozjpeg.git && cd mozjpeg \
    && git checkout v3.3.1 && autoreconf -fiv && ./configure --prefix=/opt/mozjpeg && make install

RUN git clone --recursive https://github.com/pornel/pngquant.git \
    && cd pngquant \
    && ./configure \
    && make \
    && make install

# Delete build dependencies
RUN apk del build-dependencies && rm -rf /var/cache/*
