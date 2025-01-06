##### Build stage

FROM node:20-alpine3.20 AS builder

ENV NODE_ENV=production
ENV APP_DIR=/home/node/app

RUN set -ex && \
    apk --no-cache add gcc g++ make python3 curl cmake zeromq-dev

# Create app directory
RUN mkdir "$APP_DIR"

# Copy app source files into APP_DIR
COPY ./samourai-dojo/. "$APP_DIR"

# Install node modules required by the app
RUN cd "$APP_DIR" && \
    npm install --omit=dev --build-from-source=false

##### Final stage

FROM node:20-alpine3.20

ENV NODE_ENV=production
ENV APP_DIR=/home/node/app

RUN set -ex && \
    apk --no-cache add shadow bash && \
    apk --no-cache add mariadb mariadb-client pwgen nginx yq

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
COPY ./samourai-dojo/db-scripts/ /docker-entrypoint-initdb.d

### Nginx

COPY ./samourai-dojo/docker/my-dojo/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx-dojo.conf /etc/nginx/sites-enabled/dojo.conf

### Docker entrypoint

COPY ./config.env /usr/local/bin/config.env
COPY --chmod=754 ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
