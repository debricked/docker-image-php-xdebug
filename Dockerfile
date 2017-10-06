FROM php:7.1

RUN curl -sL https://deb.nodesource.com/setup_7.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt update && apt install git zlibc zlib1g zlib1g-dev libicu-dev libpng-dev nodejs yarn libpcre3-dev -y

RUN pecl install apcu \
    && pecl install xdebug \
    && docker-php-ext-enable apcu xdebug

RUN	docker-php-ext-install exif fileinfo gd intl mbstring pdo_mysql zip

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && chmod +x /usr/bin/composer
