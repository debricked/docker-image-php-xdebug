FROM debricked/docker-image-build-tools:latest

# Fixes problems with Puppeteer (Chromium API)
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD 1
# "fake" dbus address to prevent errors
# https://github.com/SeleniumHQ/docker-selenium/issues/87
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null
ENV BIN_DIRECTORY=/usr/local/bin

RUN apt update && apt install gnupg -y

RUN apt install software-properties-common dirmngr -y

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && curl -sS https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
# Need buster-backports in order to get a recent version of go
    && echo 'deb http://deb.debian.org/debian buster-backports main' > /etc/apt/sources.list.d/backports.list \
    && mkdir -p /usr/share/man/man1

RUN apt update && apt upgrade -y \
    && apt install unzip mariadb-client git zlib1g zlib1g-dev libzip-dev libicu-dev \
    libpng-dev nodejs yarn libpcre3-dev optipng libxslt1-dev libxslt1.1 openjdk-11-jdk \
    ca-certificates p11-kit libonig-dev libgcrypt20-dev \
    sudo procps -y \
    && yarn global add bower

# Install both npm 6 and npm 7 onto the image (use 'npm6 ...' and 'npm7 ...' in order to specify version)
ENV NPM_6_NODE_VERSION 14.16.1
ENV NPM_6_NODE_DIRECTORY ${BIN_DIRECTORY}/node-${NPM_6_NODE_VERSION}
ENV NPM_7_NODE_VERSION 15.14.0
ENV NPM_7_NODE_DIRECTORY ${BIN_DIRECTORY}/node-${NPM_7_NODE_VERSION}

RUN curl -SL --output node-${NPM_6_NODE_VERSION}.tar.gz https://nodejs.org/dist/v${NPM_6_NODE_VERSION}/node-v${NPM_6_NODE_VERSION}-linux-x64.tar.xz \
    && mkdir -p "${NPM_6_NODE_DIRECTORY}" \
    && tar xf node-${NPM_6_NODE_VERSION}.tar.gz -C ${NPM_6_NODE_DIRECTORY} --strip-components 1 \
    && chmod +x "${NPM_6_NODE_DIRECTORY}/bin/npm" \
    && rm node-${NPM_6_NODE_VERSION}.tar.gz \
    && ln -s "${NPM_6_NODE_DIRECTORY}/bin/npm" "${BIN_DIRECTORY}/npm6" \
    && curl -SL --output node-${NPM_7_NODE_VERSION}.tar.gz https://nodejs.org/dist/v${NPM_7_NODE_VERSION}/node-v${NPM_7_NODE_VERSION}-linux-x64.tar.xz \
    && mkdir -p "${NPM_7_NODE_DIRECTORY}" \
    && tar xf node-${NPM_7_NODE_VERSION}.tar.gz -C ${NPM_7_NODE_DIRECTORY} --strip-components 1 \
    && chmod +x "${NPM_7_NODE_DIRECTORY}/bin/npm" \
    && rm node-${NPM_7_NODE_VERSION}.tar.gz \
    && ln -s "${NPM_7_NODE_DIRECTORY}/bin/npm" "${BIN_DIRECTORY}/npm7"

RUN cd /tmp \
    && git clone https://github.com/opsengine/cpulimit.git \
    && cd cpulimit \
    && make \
    && cp src/cpulimit /usr/bin \
    && chmod +x /usr/bin/cpulimit

# Install python and pip and related dev packages.
RUN apt update && apt install python3 python3-dev python3-pip python3-venv libffi-dev libssl-dev -y \
    && pip3 install pipenv

# Install Go from buster-backports
RUN apt install -t buster-backports golang-go -y

#install Gdub
RUN curl -L -O https://github.com/dougborg/gdub/zipball/master && unzip master && rm master \
  && gdubw-gdub-3a5eca5/install && rm -r gdubw-gdub-3a5eca5

# Chromium dependencies
RUN apt install google-chrome-stable \
    libgtk2.0-0 \
    libnotify-dev \
    libgbm-dev \
    libgconf-2-4 \
    libnss3 \
    libxss1 \
    libasound2 \
    xvfb \
    dbus-x11 -yqq > /dev/null

ENV DOTNET_ROOT ${BIN_DIRECTORY}/dotnet-3.1.300
ENV PATH $PATH:${DOTNET_ROOT}

#Install dotnet and check so that it actually works
RUN curl -SL --output dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/0c795076-b679-457e-8267-f9dd20a8ca28/02446ea777b6f5a5478cd3244d8ed65b/dotnet-sdk-3.1.300-linux-x64.tar.gz \
    && mkdir -p "${DOTNET_ROOT}" \
    && tar zxf dotnet.tar.gz -C "${DOTNET_ROOT}" \
    && chmod +x "${DOTNET_ROOT}/dotnet" \
    && rm dotnet.tar.gz \
    && ln -s "${DOTNET_ROOT}/dotnet" "${BIN_DIRECTORY}/dotnet" \
    && dotnet help

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN docker-php-ext-configure zip && docker-php-ext-configure pcntl
RUN chmod +x /usr/local/bin/install-php-extensions && sync \
    && install-php-extensions amqp apcu bcmath exif fileinfo gd pdo_mysql mysqli pcntl pdo_pgsql redis \
    sockets zip opcache intl uuid xdebug xsl \
    && docker-php-ext-install mbstring

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && chmod +x /usr/bin/composer

RUN  curl -SL --output local-php-security-checker 'https://github.com/fabpot/local-php-security-checker/releases/download/v1.0.0/local-php-security-checker_1.0.0_linux_amd64' \
    && chmod +x local-php-security-checker \
    && mv local-php-security-checker ${BIN_DIRECTORY}

RUN echo "date.timezone = UTC" >> /usr/local/etc/php/php.ini \
    && echo "opcache.enable = 1" >> /usr/local/etc/php/php.ini \
    && echo "opcache.enable_cli = 1" >> /usr/local/etc/php/php.ini \
    && echo "opcache.memory_consumption = 256" >> /usr/local/etc/php/php.ini \
    && echo "opcache.max_accelerated_files = 100000" >> /usr/local/etc/php/php.ini \
    && echo "opcache.interned_strings_buffer = 32" >> /usr/local/etc/php/php.ini \
    && echo "realpath_cache_size = 50M" >> /usr/local/etc/php/php.ini \
    && echo "apc.entries_hint = 256000" >> /usr/local/etc/php/php.ini \
    && echo "apc.shm_size = 512M" >> /usr/local/etc/php/php.ini \
    && echo "apc.enabled = 1" >> /usr/local/etc/php/php.ini \
    && echo "apc.enable_cli = 1" >> /usr/local/etc/php/php.ini \
    && echo /usr/local/etc/php/php.ini

RUN apt update && apt install automake nasm libtool -y \
    && git clone git://github.com/mozilla/mozjpeg.git && cd mozjpeg \
    && git checkout v3.3.1 && autoreconf -fiv && ./configure --prefix=/opt/mozjpeg && make install

ENV PATH="/root/.cargo/bin:${PATH}"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && git clone --recursive https://github.com/pornel/pngquant.git \
    && cd pngquant \
    && cargo build --release \
    && rustup self uninstall -y

# Install Mercure
RUN curl https://github.com/dunglas/mercure/releases/download/v0.11.3/mercure_0.11.3_Linux_x86_64.tar.gz --output /tmp/mercure.tar.gz -L \
    && tar -xzvf /tmp/mercure.tar.gz -C /tmp \
    && cp /tmp/mercure /usr/bin/mercure \
    && rm -rf /tmp/mercure* \
    && chmod +x /usr/bin/mercure

# Cleanup
RUN rm -rf /var/lib/apt/lists/* && apt clean
