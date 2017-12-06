FROM php:7.2

RUN apt update && apt install gnupg

RUN curl -sL https://deb.nodesource.com/setup_7.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt update && apt install git zlibc zlib1g zlib1g-dev libicu-dev libpng-dev nodejs yarn libpcre3-dev optipng -y

RUN curl -O https://mozjpeg.codelove.de/bin/mozjpeg_3.1_amd64.deb \ 
    && dpkg --install mozjpeg_3.1_amd64.deb \
    && apt install -f

RUN git clone --recursive https://github.com/pornel/pngquant.git \
    && cd pngquant \
    && ./configure \
    && make \
    && make install

RUN pecl install apcu \
    && pecl install xdebug-2.6.0alpha1 \
    && docker-php-ext-enable apcu xdebug

RUN docker-php-ext-install exif fileinfo gd intl mbstring pdo_mysql sockets zip

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && chmod +x /usr/bin/composer
