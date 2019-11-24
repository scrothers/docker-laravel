# Build the PHP extensions that we need.
FROM php:7.3-fpm-alpine3.10 AS builder

# Unpack the PHP source code to compile in new extensions.
RUN docker-php-source extract

# Add in various packages that we need for our PHP extensions.
RUN apk --no-cache add \
      argon2 \
      bzip2 \
      libpng \
      gettext \
      gmp \
      hiredis \
      icu \
      imagemagick \
      libbz2 \
      libmemcached \
      libzip \
      mysql-client \
      openldap-clients \
      postgresql-client \
      redis \
      yaml \
      zlib

# Add in the various dev packages that we need for our PHP extensions.
RUN apk --no-cache add --virtual .compile-deps \
      argon2-dev \
      bzip2-dev \
      libpng-dev \
      gettext-dev \
      gmp-dev \
      hiredis-dev \
      icu-dev \
      imagemagick-dev \
      libmemcached-dev \
      libzip-dev \
      openldap-dev \
      postgresql-dev \
      yaml-dev \
      zlib-dev

# Install the APK virtual dependencies into the container before we start.
RUN apk --no-cache add --virtual .phpize-deps $PHPIZE_DEPS

# Install all of the required built-in PHP extensions for usage.
RUN docker-php-ext-install \
      bcmath \
      bz2 \
      calendar \
      exif \
      gd \
      gettext \
      gmp \
      intl \
      ldap \
      mysqli \
      opcache \
      pcntl \
      pdo_mysql \
      pdo_pgsql \
      pgsql \
      shmop \
      sockets \
      zip

# Add in the various dev packages that we need to build third party extensions.
RUN apk --no-cache add --virtual .build-deps \
      autoconf \
      automake \
      git \
      libtool

# Install PHP msgpack client extension.
RUN pecl install msgpack && \
    docker-php-ext-enable msgpack

# Install PHP Redis client extension.
RUN pecl install --onlyreqdeps --nobuild redis && \
    cd "$(pecl config-get temp_dir)/redis" && \
    phpize && \
    ./configure \
      --disable-redis-igbinary \
      --enable-redis-msgpack \
      --enable-redis-lzf && \
    make && make install && \
    docker-php-ext-enable redis

# Install PHP Swoole server client extension.
RUN pecl install --onlyreqdeps --nobuild swoole && \
    cd "$(pecl config-get temp_dir)/swoole" && \
    phpize && \
    ./configure \
      --enable-sockets \
      --enable-openssl \
      --enable-http2 \
      --enable-swoole \
      --enable-mysqlnd && \
    make && make install && \
    docker-php-ext-enable swoole

# Install libmaxminddb to the system for the PHP extension.
RUN git clone --recursive https://github.com/maxmind/libmaxminddb.git \
    /tmp/libmaxminddb && \
    cd /tmp/libmaxminddb && \
    git checkout 1.4.2 && \
    ./bootstrap && ./configure && \
    make && make install

# Install the MaxMind DB extension.
RUN git clone https://github.com/maxmind/MaxMind-DB-Reader-php.git \
    "$(pecl config-get temp_dir)/maxmind" && \
    cd "$(pecl config-get temp_dir)/maxmind" && \
    git checkout v1.5.0 && \
    cd ext && phpize && \
    ./configure --with-maxminddb && \
    make && make install && \
    docker-php-ext-enable maxminddb

# Install PHP yaml client extension.
RUN yes | pecl install yaml && \
    docker-php-ext-enable yaml

# Install memcached client extension.
RUN pecl install --onlyreqdeps --nobuild memcached && \
    cd "$(pecl config-get temp_dir)/memcached" && \
    phpize && \
    ./configure \
      --enable-memcached \
      --enable-memcached-session \
      --enable-memcached-json \
      --disable-memcached-msgpack \
      --disable-memcached-igbinary && \
    make && make install && \
    docker-php-ext-enable memcached

# Install PHP mailparse client extension.
RUN pecl install mailparse && \
    docker-php-ext-enable mailparse

# Install ImageMagick client extension.
RUN yes | pecl install imagick && \
    docker-php-ext-enable imagick

# Install memcached client extension.
RUN yes no | pecl install apcu && \
    docker-php-ext-enable apcu

# Remove all the dependancies that were previously installed for compile.
RUN apk del --no-network .build-deps .compile-deps .phpize-deps && \
    docker-php-source delete && \
    rm -Rf /tmp/* && \
    rm -Rf $(pecl config-get temp_dir)/* && \
    rm -Rf /usr/src/*:x

# Install composer to the system.
RUN curl -s -o /tmp/composer-setup.php https://getcomposer.org/installer && \
    php /tmp/composer-setup.php --no-ansi --install-dir=/usr/bin --filename=composer

# Prepare to copy data from the build container to a flatter final container.
FROM php:7.3-fpm-alpine3.10

# Add in various packages that we need for our PHP extensions.
RUN apk --no-cache add \
      argon2 \
      bzip2 \
      libpng \
      gettext \
      gmp \
      hiredis \
      icu \
      imagemagick \
      libbz2 \
      libmemcached \
      libzip \
      mysql-client \
      openldap-clients \
      postgresql-client \
      redis \
      yaml \
      zlib

# Copy the libmaxminddb libraries from the build container.
COPY --from=builder /usr/local/lib/libmaxminddb.* /usr/local/lib/

# Copy the PHP extensions from the build container to the final container.
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/

# Copy the extension ini scripts from the builder to the final container.
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
