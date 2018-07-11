FROM php:7.2

RUN apt update && apt install gnupg -y

ARG DEBIAN_FRONTEND=noninteractive

# Install MariaDB, partly taken from https://github.com/docker-library/mariadb/blob/master/10.3/Dockerfile
RUN groupadd -r mysql && useradd -r -g mysql mysql
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
RUN apt install software-properties-common dirmngr -y \
    && apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8 \
    && add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://ftp.ddg.lth.se/mariadb/repo/10.3/debian stretch main' \
    && { \
		echo 'Package: *'; \
		echo 'Pin: release o=MariaDB'; \
		echo 'Pin-Priority: 999'; \
    } > /etc/apt/preferences.d/mariadb
RUN { \
		echo "mariadb-server-10.3" mysql-server/root_password password 'docker'; \
		echo "mariadb-server-10.3" mysql-server/root_password_again password 'docker'; \
	} | debconf-set-selections \
	&& apt-get update \
	&& apt-get install -y \
		mariadb-server \
                mariadb-client \
		mysql-common \
		libmariadbclient18 \
		libmariadb3 \
		socat \
# purge and re-create /var/lib/mysql with appropriate ownership
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 777 /var/run/mysqld \
# comment out a few problematic configuration values
	&& find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/' \
# don't reverse lookup hostnames, they are usually another container
    && echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf

RUN curl -sL https://deb.nodesource.com/setup_7.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN curl -sS https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-6.x.list

RUN apt update && apt upgrade -y && mkdir -p /usr/share/man/man1 && apt install openjdk-8-jre -y
RUN apt install git zlibc zlib1g zlib1g-dev libicu-dev libpng-dev nodejs yarn libpcre3-dev optipng elasticsearch -y

RUN mkdir -p /usr/share/man/man1 \ 
    && apt install procps openjdk-8-jre-headless -yqq \
    && echo "discovery.type: single-node" >> /etc/elasticsearch/elasticsearch.yml \
    && update-rc.d elasticsearch defaults 95 10

RUN curl -O https://mozjpeg.codelove.de/bin/mozjpeg_3.1_amd64.deb \ 
    && dpkg --install mozjpeg_3.1_amd64.deb \
    && apt install -f

RUN git clone --recursive https://github.com/pornel/pngquant.git \
    && cd pngquant \
    && ./configure \
    && make \
    && make install

RUN pecl install apcu \
    && pecl install xdebug \
    && docker-php-ext-enable apcu xdebug

RUN docker-php-ext-install exif fileinfo gd intl mbstring pdo_mysql opcache sockets zip

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
