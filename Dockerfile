FROM docker.cucloud.net/apache22

# persistent / runtime deps
RUN apt-get update && apt-get install -y ca-certificates curl libxml2 --no-install-recommends && rm -r /var/lib/apt/lists/*

# phpize deps
RUN apt-get update && apt-get install -y autoconf gcc libc-dev make pkg-config --no-install-recommends && rm -r /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d

#RUN mv /etc/apache2/apache2.conf /etc/apache2/apache2.conf.dist
#COPY apache2.conf /etc/apache2/apache2.conf
# it'd be nice if we could not COPY apache2.conf until the end of the Dockerfile, but its contents are checked by PHP during compilation

ENV PHP_EXTRA_BUILD_DEPS apache2-dev 
#apache2-prefork-dev
ENV PHP_EXTRA_CONFIGURE_ARGS --with-apxs2=/usr/bin/apxs2

#RUN gpg --keyserver pool.sks-keyservers.net --recv-keys F38252826ACD957EF380D39F2F7956BC5DA04B5D

ENV PHP_VERSION 5.4.38

# --enable-mysqlnd is included below because it's harder to compile after the fact the extensions are (since it's a plugin for several extensions, not an extension in itself)
RUN buildDeps=" \
		$PHP_EXTRA_BUILD_DEPS \
		bzip2 \
		file \
		libmcrypt4 \
		libcurl4-openssl-dev \
		libreadline6-dev \
		libssl-dev \
		libxml2-dev \
		libmcrypt-dev \
		libldap2-dev \
		libsasl2-dev \
	"; \
	set -x \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
	&& ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so \
	&& ln -s /usr/lib/x86_64-linux-gnu/liblber.so /usr/lib/liblber.so \
	&& curl -SL "http://php.net/get/php-$PHP_VERSION.tar.bz2/from/this/mirror" -o php.tar.bz2 \
	&& curl -SL "http://php.net/get/php-$PHP_VERSION.tar.bz2.asc/from/this/mirror" -o php.tar.bz2.asc \
#	&& gpg --verify php.tar.bz2.asc \
	&& mkdir -p /usr/src/php \
	&& tar -xf php.tar.bz2 -C /usr/src/php --strip-components=1 \
	&& rm php.tar.bz2* \
	&& cd /usr/src/php \
	&& ./configure \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		$PHP_EXTRA_CONFIGURE_ARGS \
		--disable-cgi \
		--enable-mysqlnd \
		--enable-mbstring \
		--with-curl \
		--with-openssl \
		--with-readline \
		--with-zlib \
		--with-mcrypt=static \
		--with-ldap \
		--with-ldap-sasl \
    --with-mysql=mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
	&& make -j"$(nproc)" \
	&& make install \
	&& cp /usr/src/php/php.ini-production /usr/local/etc/php/php.ini \
	&& cp /usr/src/php/libs/libphp5.so /usr/lib/apache2/modules \ 
	&& { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
#	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps \
	&& make clean

COPY docker-php-ext-* /usr/local/bin/
COPY test.php /var/www/test.php

WORKDIR /var/www

EXPOSE 80
EXPOSE 443

COPY start-apache.sh /opt/start-apache.sh
RUN chmod +x /opt/start-apache.sh

CMD ["/opt/start-apache.sh"]