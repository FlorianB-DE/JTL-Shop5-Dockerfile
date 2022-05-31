FROM composer:2.0.14

ADD https://gitlab.com/jtl-software/jtl-shop/core/-/archive/v5.1.2/core-v5.1.2.tar.gz /app
RUN sh -c "tar -xzf *.tar.gz"
RUN sh -c "rm *.tar.gz"
RUN sh -c "mv core* core"

WORKDIR /app/core/includes

RUN ["composer", "--ignore-platform-req=ext-bcmath", "--ignore-platform-req=ext-gd", "--ignore-platform-req=ext-intl", "--ignore-platform-req=ext-soap", "update"]
RUN ["composer", "--ignore-platform-req=ext-bcmath", "--ignore-platform-req=ext-gd", "--ignore-platform-req=ext-intl", "--ignore-platform-req=ext-soap", "install"]


FROM php:8.0-rc-apache-bullseye

RUN apt update && apt upgrade -y && apt autoremove -y && apt install -y libfreetype6-dev libjpeg62-turbo-dev libpng-dev\
    libicu-dev libxml2-dev libzip-dev zip libmagickwand-dev

COPY php.ini /usr/local/etc/php/php.ini
RUN a2enmod rewrite && service apache2 restart

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd intl pdo_mysql soap bcmath zip

RUN pecl install imagick && docker-php-ext-enable imagick

COPY --from=0 /app/core ./

ARG DATABASE_USER=root
ARG DATABASE_PASS=root
ARG DATABASE_HOST=host.docker.internal
ARG DATABASE_SOCKET=/var/run/mysqld/mysqld.sock
ARG DATABASE_DATABASE=database
ARG ADMIN_USER=admin
ARG ADMIN_PASS=password
ARG ADD_DEMO_DATA=false
ARG SHOP_URL=localhost

COPY config.JTL-Shop.ini.php includes/

RUN printf "$(cat includes/config.JTL-Shop.ini.php)"  \
    $SHOP_URL $DATABASE_HOST $DATABASE_DATABASE $DATABASE_USER $DATABASE_PASS $DATABASE_SOCKET  \
    > includes/config.JTL-Shop.ini.php


RUN ["chown", "-R", "www-data:www-data", "../html"]
RUN ["rm", "includes/config.JTL-Shop.ini.initial.php"]

CMD if [ "$ADD_DEMO_DATA" = "true" ] ; then php cli generate:demodata ; fi && apachectl -D FOREGROUND