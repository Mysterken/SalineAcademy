#syntax=docker/dockerfile:1.4

# Versions
FROM php:8.2-fpm-alpine AS php_upstream
FROM mlocati/php-extension-installer:2 AS php_extension_installer_upstream
FROM composer/composer:2-bin AS composer_upstream
FROM caddy:2-alpine AS caddy_upstream

# The different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/develop/develop-images/multistage-build/#stop-at-a-specific-build-stage
# https://docs.docker.com/compose/compose-file/#target

# Base PHP image
FROM php_upstream AS php_base

WORKDIR /srv/app

RUN docker-php-ext-install pdo_mysql

# persistent / runtime deps
RUN apk add --no-cache \
		acl \
		fcgi \
		file \
		gettext \
		git \
		make \
		autoconf \
		build-base \
	;

# php extensions installer: https://github.com/mlocati/docker-php-extension-installer
COPY --from=php_extension_installer_upstream --link /usr/bin/install-php-extensions /usr/local/bin/

RUN set -eux; \
    install-php-extensions \
    	intl \
    	zip \
    	apcu \
		opcache \
    ;

###> recipes ###
###< recipes ###

COPY --link docker/php/conf.d/app.ini $PHP_INI_DIR/conf.d/

COPY --link docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
RUN mkdir -p /var/run/php

COPY --link docker/php/docker-healthcheck.sh /usr/local/bin/docker-healthcheck
RUN chmod +x /usr/local/bin/docker-healthcheck

HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD ["docker-healthcheck"]

COPY --link docker/php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="${PATH}:/root/.composer/vendor/bin"

COPY --from=composer_upstream --link /composer /usr/bin/composer


# Dev PHP image
FROM php_base AS php_dev

ENV APP_ENV=dev XDEBUG_MODE=off
VOLUME /srv/app/var/

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

RUN set -eux; \
	install-php-extensions \
    	xdebug \
    ;

COPY --link docker/php/conf.d/app.dev.ini $PHP_INI_DIR/conf.d/

# Prod PHP image
FROM php_base AS php_prod

ENV APP_ENV=prod

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY --link docker/php/conf.d/app.prod.ini $PHP_INI_DIR/conf.d/

# prevent the reinstallation of vendors at every changes in the source code
COPY --link ./SalineAcademyBackend/composer.* ./SalineAcademyBackend/symfony.* ./
RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

# copy sources
COPY --link  ./SalineAcademyBackend ./

RUN set -eux; \
	mkdir -p var/cache var/log; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer dump-env prod; \
	composer run-script --no-dev post-install-cmd; \
	chmod +x bin/console; sync;

EXPOSE ${PHP_PORT}


# Frontend server
FROM node:lts-alpine3.17 AS app_node

ENV NODE_PORT ${NODE_PORT}

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY ./SalineAcademyFrontend/package.json ./
COPY ./SalineAcademyFrontend/yarn.lock ./

RUN set -eux; \
	yarn install \
    && yarn cache clean --all

COPY ./SalineAcademyFrontend/vite.config.js ./
COPY ./SalineAcademyFrontend/index.html ./
COPY ./SalineAcademyFrontend/public ./public
COPY ./SalineAcademyFrontend/src ./src

COPY --link docker/node/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

EXPOSE ${NODE_PORT}
ENTRYPOINT ["docker-entrypoint"]


# Dev image
FROM app_node AS app_node_dev

ENV APP_ENV=dev
VOLUME /srv/app/var/
CMD ["yarn", "dev"]


# Prod image
FROM app_node AS app_node_prod

ENV APP_ENV=prod
CMD ["yarn", "build"]


# Base Caddy image
FROM caddy_upstream AS caddy_base

ARG TARGETARCH

WORKDIR /srv/app

# Download Caddy compiled with the Mercure and Vulcain modules
ADD --chmod=500 https://caddyserver.com/api/download?os=linux&arch=$TARGETARCH&p=github.com/dunglas/mercure/caddy&p=github.com/dunglas/vulcain/caddy /usr/bin/caddy

COPY --link docker/caddy/Caddyfile /etc/caddy/Caddyfile

# Prod Caddy image
FROM caddy_base AS caddy_prod

COPY --from=php_prod --link /srv/app/public public/
