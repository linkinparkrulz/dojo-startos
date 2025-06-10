##### Build stage

FROM node:20-alpine3.20 AS builder

ENV NODE_ENV=production
ENV APP_DIR=/home/node/app

RUN set -ex && \
    apk --no-cache add gcc g++ make python3 curl cmake zeromq-dev

# Create app directory and copy source
RUN mkdir "$APP_DIR"
COPY ./samourai-dojo/. "$APP_DIR"

# Install node modules
RUN cd "$APP_DIR" && \
    npm install --omit=dev --build-from-source=false

##### Tor build stage

FROM alpine:3.20 AS torproject

ENV     TOR_GIT_URL     https://git.torproject.org/tor.git
ENV     TOR_VERSION     tor-0.4.8.16

RUN     apk --update --no-cache add ca-certificates
RUN     apk --no-cache add alpine-sdk automake autoconf git
RUN     apk --no-cache add openssl-dev libevent-dev zlib-dev

RUN     git clone $TOR_GIT_URL /tor -b $TOR_VERSION --depth 1

WORKDIR /tor

RUN     ./autogen.sh

RUN     ./configure                                           \
        --disable-system-torrc                                \
        --disable-asciidoc                                    \
        --disable-unittests                                   \
        --prefix=/stage

RUN     make -j 4 && make install

RUN     cp /stage/etc/tor/torrc.sample /stage/.torrc

##### Soroban Go build stage

FROM golang:1.22.8-alpine3.20 AS soroban-build

ENV     SOROBAN_VERSION         0.4.1
ENV     SOROBAN_URL             https://github.com/Dojo-Open-Source-Project/soroban/archive/refs/tags/v$SOROBAN_VERSION.tar.gz

RUN     apk --no-cache --update add ca-certificates
RUN     apk --no-cache --update add alpine-sdk linux-headers wget

RUN     set -ex && \
        mkdir -p /stage && \
        mkdir -p /src && \
        cd ~ && \
        wget -qO soroban.tar.gz "$SOROBAN_URL" && \
        tar -xzvf soroban.tar.gz -C /src --strip-components 1 && \
        rm soroban.tar.gz && \
        cd /src

WORKDIR /src
RUN     go mod download
RUN     go build -a -tags netgo -o /stage/soroban-server ./cmd/server

##### Final stage

FROM node:20-alpine3.20

ENV NODE_ENV=production
ENV APP_DIR=/home/node/app
ENV SOROBAN_HOME=/home/soroban

RUN set -ex && \
    apk --no-cache add shadow bash && \
    apk --no-cache add mariadb mariadb-client pwgen nginx yq curl netcat-openbsd && \
    apk --no-cache add openssl libevent zlib

### Node

RUN npm install -g pm2 && rm -rf /root/.npm/

COPY --chown=node:node --from=builder $APP_DIR $APP_DIR
COPY --chown=node:node ./samourai-dojo/docker/my-dojo/node/keys.index.js "$APP_DIR/keys/index.js"
COPY --chown=node:node ./samourai-dojo/docker/my-dojo/node/pm2.config.cjs "$APP_DIR/pm2.config.cjs"
COPY --chown=node:node --chmod=754 ./samourai-dojo/docker/my-dojo/node/restart.sh "$APP_DIR/restart.sh"
COPY --chown=node:node --chmod=754 ./samourai-dojo/docker/my-dojo/node/wait-for-it.sh "$APP_DIR/wait-for-it.sh"

### Mysql

RUN rm -f /etc/my.cnf.d/*
COPY ./samourai-dojo/docker/my-dojo/mysql/mysql-low_mem.cnf /etc/my.cnf.d/mysql-dojo.cnf
COPY ./samourai-dojo/db-scripts/1_db.sql /docker-entrypoint-initdb.d/1_db.sql
COPY ./samourai-dojo/db-scripts/2_update.sql /docker-entrypoint-initdb.d/2_update.sql

### Tor

COPY --from=torproject /stage /usr/local

### Soroban

COPY --from=soroban-build /stage/soroban-server /usr/local/bin

# Create soroban user and group
RUN addgroup -g 1001 -S soroban && \
    adduser --system --ingroup soroban --uid 1001 soroban

# Create Soroban data directory
RUN mkdir "$SOROBAN_HOME/data" && \
    chown -h soroban:soroban "$SOROBAN_HOME/data"

# Copy Tor config for Soroban
RUN cp /usr/local/etc/tor/torrc.sample /home/soroban/.torrc && \
    chown soroban:soroban /home/soroban/.torrc

# Copy Soroban scripts
COPY --chown=soroban:soroban --chmod=754 ./samourai-dojo/docker/my-dojo/soroban/restart.sh /usr/local/bin/soroban-restart.sh
COPY --chown=soroban:soroban --chmod=754 ./samourai-dojo/docker/my-dojo/soroban/healthcheck.sh /usr/local/bin/soroban-healthcheck.sh

### Nginx

COPY ./samourai-dojo/docker/my-dojo/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx/*.conf /etc/nginx/sites-available/
RUN mkdir /etc/nginx/sites-enabled && \
    ln -sf /etc/nginx/sites-available/mainnet.conf /etc/nginx/sites-enabled/dojo.conf

### Docker entrypoint

COPY ./config.env /usr/local/bin/config.env
COPY --chmod=755 ./docker_entrypoint.sh /usr/local/bin/
COPY --chmod=755 ./check-synced.sh /usr/local/bin/
COPY --chmod=755 ./check-api.sh /usr/local/bin/
COPY --chmod=755 ./check-mysql.sh /usr/local/bin/
COPY --chmod=755 ./check-pushtx.sh /usr/local/bin/
COPY --chmod=755 ./check-soroban.sh /usr/local/bin/
COPY --chmod=755 ./functions.sh /usr/local/bin/
