FROM php:7.3-fpm

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
# Fixes problems with Puppeteer (Chromium API)
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD 1
# "fake" dbus address to prevent errors
# https://github.com/SeleniumHQ/docker-selenium/issues/87
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

RUN apt update && apt install gnupg -y

RUN apt install software-properties-common dirmngr -y

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    curl -sS https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list && \
# Need backports for openjdk 11 package
    echo 'deb http://deb.debian.org/debian stretch-backports main' > /etc/apt/sources.list.d/backports.list && \
    mkdir -p /usr/share/man/man1

RUN apt update && apt upgrade -y && apt install mysql-client git zlibc zlib1g zlib1g-dev libzip-dev libicu-dev \
    libpng-dev nodejs yarn libpcre3-dev optipng libxslt1-dev libxslt1.1 openjdk-11-jdk ca-certificates p11-kit -y

# update "cacerts" bundle to use Debian's CA certificates (and make sure it stays up-to-date with changes to Debian's store)
# see https://github.com/docker-library/openjdk/issues/327
#     http://rabexc.org/posts/certificates-not-working-java#comment-4099504075
#     https://salsa.debian.org/java-team/ca-certificates-java/blob/3e51a84e9104823319abeb31f880580e46f45a98/debian/jks-keystore.hook.in
#     https://git.alpinelinux.org/aports/tree/community/java-cacerts/APKBUILD?id=761af65f38b4570093461e6546dcf6b179d2b624#n29
RUN export JAVA_HOME=$(readlink -f /usr/bin/javac | sed "s:/bin/javac::") && echo "JAVA_HOME is set to: $JAVA_HOME" && set -eux; \
    { \
    		echo '#!/usr/bin/env bash'; \
    		echo 'set -Eeuo pipefail'; \
    		#echo 'JAVA_HOME=$(readlink -f /usr/bin/javac | sed "s:/bin/javac::")'; \
    		echo 'if [ -z "${JAVA_HOME}" ]; then echo >&2 "error: missing JAVA_HOME environment variable"; exit 1; fi'; \
# 8-jdk uses "$JAVA_HOME/jre/lib/security/cacerts" and 8-jre and 11+ uses "$JAVA_HOME/lib/security/cacerts" directly (no "jre" directory)
    		echo 'cacertsFile=; for f in "$JAVA_HOME/lib/security/cacerts" "$JAVA_HOME/jre/lib/security/cacerts"; do if [ -e "$f" ]; then cacertsFile="$f"; break; fi; done'; \
    		echo 'if [ -z "$cacertsFile" ] || ! [ -f "$cacertsFile" ]; then echo >&2 "error: failed to find cacerts file in $JAVA_HOME"; exit 1; fi'; \
    		echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$cacertsFile"'; \
    } > /etc/ca-certificates/update.d/docker-openjdk; \
    chmod +x /etc/ca-certificates/update.d/docker-openjdk; \
    /etc/ca-certificates/update.d/docker-openjdk; \
# https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
    find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
    ldconfig; \
# basic smoke test
    javac --version; \
    java --version

# Chromium dependencies
RUN apt install google-chrome-stable \
    libgtk2.0-0 \
    libnotify-dev \
    libgconf-2-4 \
    libnss3 \
    libxss1 \
    libasound2 \
    xvfb \
    dbus-x11 -yqq > /dev/null

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

RUN echo "date.timezone = UTC" >> /usr/local/etc/php/php.ini \
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

RUN apt install automake nasm libtool -y && git clone git://github.com/mozilla/mozjpeg.git && cd mozjpeg \
    && git checkout v3.3.1 && autoreconf -fiv && ./configure --prefix=/opt/mozjpeg && make install

RUN git clone --recursive https://github.com/pornel/pngquant.git \
    && cd pngquant \
    && ./configure \
    && make \
    && make install

# Cleanup
RUN rm -rf /var/lib/apt/lists/* && apt clean
