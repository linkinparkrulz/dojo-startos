FROM --platform=linux/arm64/v8 mariadb:10.7.1 as db-builder

COPY    samourai-dojo/docker/my-dojo/mysql/*.cnf /etc/mysql/conf.d/
COPY    samourai-dojo/docker/my-dojo/mysql/update-db.sh /update-db.sh
RUN     chmod u+x /update-db.sh && \
        chmod g+x /update-db.sh
COPY    samourai-dojo/db-scripts/ /docker-entrypoint-initdb.d

# FROM --platform=linux/arm64/v8 node:16-alpine AS builder

# ENV     NODE_ENV    production
# ENV     APP_DIR     /home/node/app
# RUN     set -ex && apk --no-cache add gcc g++ make python3 curl cmake
# RUN     set -ex && npm i -g npm
# RUN     mkdir "$APP_DIR"
# COPY    samourai-dojo/ "$APP_DIR"
# RUN     cd "$APP_DIR" && npm install --omit=dev

# FROM --platform=linux/arm64/v8 node:16-alpine as final

# RUN apk add tini bash curl yq nginx && rm -f /var/cache/apk/*

# ENV     NODE_ENV    production
# ENV     APP_DIR     /home/node/app
# # ARG     TOR_LINUX_GID
# RUN     set -ex && apk --no-cache add shadow bash
# # RUN     addgroup -S -g ${TOR_LINUX_GID} tor && usermod -a -G tor node
# RUN     npm install -g pm2

# COPY    --from=builder $APP_DIR $APP_DIR
# COPY    samourai-dojo/docker/my-dojo/node/keys.index.js "$APP_DIR/keys/index.js"
# COPY    samourai-dojo/docker/my-dojo/node/pm2.config.cjs "$APP_DIR/pm2.config.cjs"
# COPY    samourai-dojo/docker/my-dojo/node/restart.sh "$APP_DIR/restart.sh"
# RUN     chmod u+x "$APP_DIR/restart.sh" && \
#         chmod g+x "$APP_DIR/restart.sh"
# COPY    samourai-dojo/docker/my-dojo/node/wait-for-it.sh "$APP_DIR/wait-for-it.sh"
# RUN     chmod u+x "$APP_DIR/wait-for-it.sh" && \
#         chmod g+x "$APP_DIR/wait-for-it.sh"
# RUN     chown -R node:node "$APP_DIR"

# COPY samourai-dojo/docker/my-dojo/conf/ ./conf/ 
# COPY samourai-dojo/docker/my-dojo/.env ./.env 
# COPY samourai-dojo/docker/my-dojo/nginx/nginx.conf /etc/nginx/nginx.conf
# COPY samourai-dojo/docker/my-dojo/nginx/explorer.conf /etc/nginx/sites-enabled/dojo-explorer.conf
# COPY samourai-dojo/docker/my-dojo/nginx/whirlpool.conf /etc/nginx/sites-enabled/dojo-whirlpool.conf
# # Copy wait-for script
# COPY samourai-dojo/docker/my-dojo/nginx/wait-for /wait-for

# RUN chmod u+x /wait-for && chmod g+x /wait-for

# COPY --from=db-builder /var/lib/mysql /var/lib/mysql
# COPY --from=db-builder /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d
# COPY --from=db-builder /etc/mysql/conf.d/ /etc/mysql/conf.d/

ADD docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
ADD assets/utils/check-web.sh /usr/local/bin/check-web.sh
ADD assets/utils/check-api.sh /usr/local/bin/check-api.sh
RUN chmod a+x /usr/local/bin/*.sh
