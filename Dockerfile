FROM composer:2.0.14

ADD https://gitlab.com/jtl-software/jtl-shop/core/-/archive/v5.1.2/core-v5.1.2.tar.gz /app
RUN sh -c "tar -xzf *.tar.gz"
RUN sh -c "rm *.tar.gz"
RUN sh -c "mv core* core"

WORKDIR /app/core/includes

RUN ["composer", "--ignore-platform-req=ext-bcmath", "--ignore-platform-req=ext-gd", "--ignore-platform-req=ext-intl", "--ignore-platform-req=ext-soap", "update"]
RUN ["composer", "--ignore-platform-req=ext-bcmath", "--ignore-platform-req=ext-gd", "--ignore-platform-req=ext-intl", "--ignore-platform-req=ext-soap", "install"]


FROM php:8.0-rc-apache-bullseye

ENV DATABASE_USER=root DATABASE_PASS=root DATABASE_HOST=host.docker.internal
ENV DATABASE_DATABASE=database ADMIN_USER=admin ADMIN_PASS=password ADD_DEMO_DATA=false SHOP_URL=localhost

RUN apt update && apt install -y libfreetype6-dev libjpeg62-turbo-dev libpng-dev\
    libicu-dev libxml2-dev libzip-dev zip libmagickwand-dev

COPY php.ini /usr/local/etc/php/php.ini
RUN a2enmod rewrite && service apache2 restart

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd intl pdo_mysql soap bcmath zip

RUN pecl install imagick && docker-php-ext-enable imagick

COPY --from=0 /app/core ./

COPY config.JTL-Shop.ini.php includes/


RUN ["chown", "-R", "www-data:www-data", "../html"]
RUN ["rm", "includes/config.JTL-Shop.ini.initial.php"]



CMD printf "$(cat includes/config.JTL-Shop.ini.php)"  \
    $SHOP_URL $DATABASE_HOST $DATABASE_DATABASE $DATABASE_USER $DATABASE_PASS > includes/config.JTL-Shop.ini.php && \
    if [ "$ADD_DEMO_DATA" = "true" ] ; then php cli generate:demodata ; fi && apachectl -D FOREGROUND