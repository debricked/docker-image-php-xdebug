FROM php:8.3-fpm

ENV BIN_DIRECTORY=/usr/local/bin
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

RUN apt update && apt upgrade -y \
    && apt install -y gnupg p11-kit openjdk-11-jdk unzip

RUN curl -L -O https://download.java.net/openjdk/jdk7u75/ri/jdk_ri-7u75-b13-linux-x64-18_dec_2014.tar.gz \
    && tar -xvf jdk_ri-7u75-b13-linux-x64-18_dec_2014.tar.gz \
    && mkdir -p /usr/lib/jvm \
    && mv java-se-7u75-ri /usr/lib/jvm \
    && rm jdk_ri-7u75-b13-linux-x64-18_dec_2014.tar.gz

RUN curl -L -O https://download.java.net/openjdk/jdk8u40/ri/jdk_ri-8u40-b25-linux-x64-10_feb_2015.tar.gz \
    && tar -xvf jdk_ri-8u40-b25-linux-x64-10_feb_2015.tar.gz \
    && mv java-se-8u40-ri /usr/lib/jvm \
    && rm jdk_ri-8u40-b25-linux-x64-10_feb_2015.tar.gz

RUN curl -L -O https://download.java.net/java/GA/jdk9/9.0.4/binaries/openjdk-9.0.4_linux-x64_bin.tar.gz \
    && tar -xvf openjdk-9.0.4_linux-x64_bin.tar.gz \
    && mv jdk-9.0.4 /usr/lib/jvm \
    && rm openjdk-9.0.4_linux-x64_bin.tar.gz

RUN curl -L -O https://download.java.net/java/GA/jdk10/10.0.2/19aef61b38124481863b1413dce1855f/13/openjdk-10.0.2_linux-x64_bin.tar.gz \
    && tar -xvf openjdk-10.0.2_linux-x64_bin.tar.gz \
    && mv jdk-10.0.2 /usr/lib/jvm \
    && rm openjdk-10.0.2_linux-x64_bin.tar.gz

RUN update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/java-se-7u75-ri/bin/java" 1 \
    && update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/java-se-8u40-ri/bin/java" 1 \
    && update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-9.0.4/bin/java" 1 \
    && update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-10.0.2/bin/java" 1

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
#Manually add certificates for some maven and gradle repositories to java 8 and 10 since they aren't added automatically
    java_version=8; \
    java_certificates="java-se-8u40-ri/jre/lib/security/cacerts jdk-10.0.2/lib/security/cacerts"; \
    for java_certificate in ${java_certificates}; do \
        openssl s_client -showcerts -connect dl.google.com:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >dlGoogle.PEM; \
        yes | keytool -import -alias "dlGoogleCert$java_version" -keystore "/usr/lib/jvm/$java_certificate" -file dlGoogle.PEM -storepass changeit; \
        openssl s_client -showcerts -connect maven.fabric.io:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >mavenFabricIo.PEM; \
        yes | keytool -import -alias "mavenFabricIoCert$java_version" -keystore "/usr/lib/jvm/$java_certificate" -file mavenFabricIo.PEM -storepass changeit; \
        openssl s_client -showcerts -connect bintray.com:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >bintray.PEM; \
        yes | keytool -import -alias "bintrayCert$java_version" -keystore "/usr/lib/jvm/$java_certificate" -file bintray.PEM -storepass changeit; \
        openssl s_client -showcerts -connect jfrog.com:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >jfrogCom.PEM; \
        yes | keytool -import -alias "jfrogComCert$java_version" -keystore "/usr/lib/jvm/$java_certificate" -file jfrogCom.PEM -storepass changeit; \
        openssl s_client -showcerts -connect repo1.maven.org:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >mavenOrg.PEM; \
        yes | keytool -import -alias "mavenOrgCert$java_version" -keystore "/usr/lib/jvm/$java_certificate" -file mavenOrg.PEM -storepass changeit; \
        rm mavenOrg.PEM; \
        rm jfrogCom.PEM; \
        rm bintray.PEM; \
        rm mavenFabricIo.PEM; \
        rm dlGoogle.PEM; \
        java_version=10; \
    done; \
# https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
    find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
    ldconfig; \
# basic smoke test
    javac --version; \
    java --version

#install Maven
ENV MAVEN_VERSION 3.6.3
ENV M2_HOME $BIN_DIRECTORY/maveninstallation
ENV MAVEN_HOME $BIN_DIRECTORY/maveninstallation
ENV PATH $MAVEN_HOME/bin:$PATH

RUN curl -L -O http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
  && tar -zxvf apache-maven-$MAVEN_VERSION-bin.tar.gz \
  && rm apache-maven-$MAVEN_VERSION-bin.tar.gz \
  && mv apache-maven-$MAVEN_VERSION $BIN_DIRECTORY/maveninstallation \
  && ln -s $BIN_DIRECTORY/maveninstallation/bin/mvn $BIN_DIRECTORY/mvn

#install Gradle
ENV GRADLE_VERSION 5.5.1

RUN cd / \
    && curl -L -O https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
    && unzip -d $BIN_DIRECTORY/gradleinstallation gradle-${GRADLE_VERSION}-bin.zip \
    && rm /gradle-${GRADLE_VERSION}-bin.zip \
    && ln -s $BIN_DIRECTORY/gradleinstallation/gradle-${GRADLE_VERSION}/bin/gradle $BIN_DIRECTORY/gradle

ENV GRADLE_HOME $BIN_DIRECTORY/gradleinstallation/gradle-${GRADLE_VERSION}
ENV PATH ${GRADLE_HOME}/bin:${PATH}

# Set the environment and URL
ENV JAVA_OPTS='-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'

ENV SDK_URL="https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip" \
    ANDROID_HOME="/usr/local/android-sdk" \
    ANDROID_VERSION=29 \
    ANDROID_BUILD_TOOLS_VERSION=29.0.1

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

# Install Bazel build tool

ENV BAZEL1_VERSION 1.2.1
RUN curl https://bazel.build/bazel-release.pub.gpg | apt-key add - \
    && echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list \
    && apt update && apt install -y bazel-$BAZEL1_VERSION \
    && ln -s /usr/bin/bazel-$BAZEL1_VERSION $BIN_DIRECTORY/bazel1

ENV BAZEL2_VERSION 2.2.0
RUN curl https://bazel.build/bazel-release.pub.gpg | apt-key add - \
    && echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list \
    && apt update && apt install -y bazel-$BAZEL2_VERSION \
    && ln -s /usr/bin/bazel-$BAZEL2_VERSION $BIN_DIRECTORY/bazel2

ENV BAZEL3_VERSION 3.7.2
RUN curl https://bazel.build/bazel-release.pub.gpg | apt-key add - \
    && echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list \
    && apt update && apt install -y bazel-$BAZEL3_VERSION \
    && ln -s /usr/bin/bazel-$BAZEL3_VERSION $BIN_DIRECTORY/bazel3

ENV BAZEL4_VERSION 4.1.0
RUN curl https://bazel.build/bazel-release.pub.gpg | apt-key add - \
    && echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list \
    && apt update && apt install -y bazel-$BAZEL4_VERSION \
    && ln -s /usr/bin/bazel-$BAZEL4_VERSION $BIN_DIRECTORY/bazel4 \
    && ln -s /usr/bin/bazel-$BAZEL4_VERSION $BIN_DIRECTORY/bazel
