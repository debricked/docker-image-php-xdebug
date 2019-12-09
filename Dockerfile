FROM php:7.4-fpm

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

RUN apt update && apt upgrade -y && apt install unzip mariadb-client git zlibc zlib1g zlib1g-dev libzip-dev libicu-dev \
    libpng-dev nodejs yarn libpcre3-dev optipng libxslt1-dev libxslt1.1 openjdk-11-jdk ca-certificates p11-kit \
    libonig-dev libgcrypt20-dev -y \
    && yarn global add bower

RUN cd /tmp && git clone https://github.com/opsengine/cpulimit.git && cd cpulimit && make && \
    cp src/cpulimit /usr/bin && chmod +x /usr/bin/cpulimit

RUN curl -L -O https://download.java.net/openjdk/jdk7u75/ri/jdk_ri-7u75-b13-linux-x64-18_dec_2014.tar.gz && \
    tar -xvf jdk_ri-7u75-b13-linux-x64-18_dec_2014.tar.gz && \
    mkdir -p /usr/lib/jvm && \
    mv java-se-7u75-ri /usr/lib/jvm && \ 
    rm jdk_ri-7u75-b13-linux-x64-18_dec_2014.tar.gz

RUN curl -L -O https://download.java.net/openjdk/jdk8u40/ri/jdk_ri-8u40-b25-linux-x64-10_feb_2015.tar.gz && \
    tar -xvf jdk_ri-8u40-b25-linux-x64-10_feb_2015.tar.gz && \
    mv java-se-8u40-ri /usr/lib/jvm && \
    rm jdk_ri-8u40-b25-linux-x64-10_feb_2015.tar.gz

RUN curl -L -O https://download.java.net/java/GA/jdk9/9.0.4/binaries/openjdk-9.0.4_linux-x64_bin.tar.gz && \
    tar -xvf openjdk-9.0.4_linux-x64_bin.tar.gz && \
    mv jdk-9.0.4 /usr/lib/jvm && \
    rm openjdk-9.0.4_linux-x64_bin.tar.gz

RUN curl -L -O https://download.java.net/java/GA/jdk10/10.0.2/19aef61b38124481863b1413dce1855f/13/openjdk-10.0.2_linux-x64_bin.tar.gz && \
    tar -xvf openjdk-10.0.2_linux-x64_bin.tar.gz && \
    mv jdk-10.0.2 /usr/lib/jvm && \
    rm openjdk-10.0.2_linux-x64_bin.tar.gz

RUN update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/java-se-7u75-ri/bin/java" 1 && \
     update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/java-se-8u40-ri/bin/java" 1 && \
     update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-9.0.4/bin/java" 1 && \
     update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-10.0.2/bin/java" 1 

ENV JAVA_HOME="/usr/lib/jvm/jdk-9.0.4"
ENV JAVA_HOME7="/usr/lib/jvm/java-se-7u75-ri"
ENV JAVA_HOME8="/usr/lib/jvm/java-se-8u40-ri"
ENV JAVA_HOME9="/usr/lib/jvm/jdk-9.0.4"
ENV JAVA_HOME10="/usr/lib/jvm/jdk-10.0.2"
ENV JAVA_HOME11="/usr/lib/jvm/java-11-openjdk-amd64"

# update "cacerts" bundle to use Debian's CA certificates (and make sure it stays up-to-date with changes to Debian's store)
# see https://github.com/docker-library/openjdk/issues/327
#     http://rabexc.org/posts/certificates-not-working-java#comment-4099504075
#     https://salsa.debian.org/java-team/ca-certificates-java/blob/3e51a84e9104823319abeb31f880580e46f45a98/debian/jks-keystore.hook.in
#     https://git.alpinelinux.org/aports/tree/community/java-cacerts/APKBUILD?id=761af65f38b4570093461e6546dcf6b179d2b624#n29
RUN echo "JAVA_HOME is set to: $JAVA_HOME" && set -eux; \
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
\
#Manually add certificates for dl.google.com and repo.jfrog.org to java 10.0.2 since they aren't added automatically
    openssl s_client -showcerts -connect repo.jfrog.org:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >jfrog.PEM; \
    yes | keytool -import -alias jfrogCert -keystore /usr/lib/jvm/jdk-10.0.2/lib/security/cacerts -file jfrog.PEM -storepass changeit; \
    openssl s_client -showcerts -connect dl.google.com:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >dlGoogle.PEM; \
    yes | keytool -import -alias dlGoogleCert -keystore /usr/lib/jvm/jdk-10.0.2/lib/security/cacerts -file dlGoogle.PEM -storepass changeit; \
    rm dlGoogle.PEM; \
    rm jfrog.PEM; \
# https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
    find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
    ldconfig; \
# basic smoke test
    javac --version; \
    java --version

#install Maven
ENV MAVEN_VERSION 3.6.2

RUN curl -L -O http://www-eu.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    tar xzf apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    ln -s apache-maven-${MAVEN_VERSION} apache-maven && \
    mv apache-maven-${MAVEN_VERSION} /usr/lib && \
    rm apache-maven-${MAVEN_VERSION}-bin.tar.gz

ENV M2_HOME /usr/lib/mvn
ENV MAVEN_HOME /usr/lib/apache-maven-${MAVEN_VERSION}
ENV PATH $MAVEN_HOME/bin:$PATH

#install Gradle
ENV GRADLE_VERSION 5.5.1

RUN cd / \
    && curl -L -O https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
    && unzip -d /opt/gradle gradle-${GRADLE_VERSION}-bin.zip \
    && rm /gradle-${GRADLE_VERSION}-bin.zip

ENV GRADLE_HOME /opt/gradle/gradle-${GRADLE_VERSION}
ENV PATH ${GRADLE_HOME}/bin:${PATH}

#install Gdub
RUN curl -L -O https://github.com/dougborg/gdub/zipball/master && unzip master && rm master \ 
  && dougborg-gdub-ebe14f1/install && rm -r dougborg-gdub-ebe14f1

# Set the environment and URL
ENV JAVA_OPTS='-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'

ENV SDK_URL="https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip" \
    ANDROID_HOME="/usr/local/android-sdk" \
    ANDROID_VERSION=29 \
    ANRDROID_BUILD_TOOLS_VESION=29.0.1

# Download Android SDK
RUN mkdir "$ANDROID_HOME" .android \
    && cd "$ANDROID_HOME" \
    && curl -o sdk.zip $SDK_URL \
    && unzip sdk.zip \
    && rm sdk.zip \
    && yes | $ANDROID_HOME/tools/bin/sdkmanager --licenses

RUN echo "### User Sources for Android SDK Manager" > ~/.android/repositories.cfg && echo "#Fri Nov 03 10:11:27 CET 2017 count=0" >> ~/.android/repositories.cfg 

# Install Android Build Tool and Libraries
RUN $ANDROID_HOME/tools/bin/sdkmanager --update

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
    && pecl install xdebug-2.9.0 \
    && docker-php-ext-enable apcu xdebug

RUN pecl install -o -f redis \
  &&  rm -rf /tmp/pear \
  &&  docker-php-ext-enable redis

RUN docker-php-ext-configure zip
RUN docker-php-ext-install exif fileinfo gd intl mbstring pdo_mysql mysqli opcache sockets zip xsl

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
