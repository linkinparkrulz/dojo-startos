#!/bin/bash
set -ea

_term() { 
  echo "Caught SIGTERM signal!"
  kill -TERM "$backend_process" 2>/dev/null
  kill -TERM "$db_process" 2>/dev/null
  kill -TERM "$frontend_process" 2>/dev/null
}

source /usr/local/bin/config.env

# DATABASE SETUP
if [ -d "/run/mysqld" ]; then
	echo "[i] mysqld already present, skipping creation"
	chown -R mysql:mysql /run/mysqld
else
	echo "[i] mysqld not found, creating...."
	mkdir -p /run/mysqld
	chown -R mysql:mysql /run/mysqld
fi

if [ -d /var/lib/mysql/mysql ]; then
	echo "[i] MySQL directory already present, skipping creation"
	chown -R mysql:mysql /var/lib/mysql
else
	echo "[i] MySQL data directory not found, creating initial DBs"

	mkdir -p /var/lib/mysql
	chown -R mysql:mysql /var/lib/mysql

	mysql_install_db --user=mysql --ldata=/var/lib/mysql > /dev/null

	if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
		MYSQL_ROOT_PASSWORD=$(pwgen 16 1)
		echo "[i] MySQL root Password: $MYSQL_ROOT_PASSWORD"
		export MYSQL_ROOT_PASSWORD
	fi

	MYSQL_DATABASE=${MYSQL_DATABASE:-"samourai-main"}
	MYSQL_USER=${MYSQL_USER:-"samourai"}
	MYSQL_PASSWORD=${MYSQL_PASSWORD:-"samourai"}

	tfile=$(mktemp)
	if [ ! -f "$tfile" ]; then
		return 1
	fi

	cat << EOF > "$tfile"
USE mysql;
FLUSH PRIVILEGES ;
GRANT ALL ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
GRANT ALL ON *.* TO 'root'@'localhost' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
DROP DATABASE IF EXISTS test ;
FLUSH PRIVILEGES ;
EOF

	if [ "$MYSQL_DATABASE" != "" ]; then
		echo "[i] Creating database: $MYSQL_DATABASE"
		echo "[i] with character set: 'utf8' and collation: 'utf8_general_ci'"
		echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> "$tfile"

		if [ "$MYSQL_USER" != "" ]; then
			echo "[i] Creating user: $MYSQL_USER with password $MYSQL_PASSWORD"

			{
				echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';"
				echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
				echo "FLUSH PRIVILEGES;"
			} >> "$tfile"
		fi
	fi

	/usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0 < "$tfile"

	rm -f "$tfile"

	for f in /docker-entrypoint-initdb.d/*; do
		case "$f" in
			*.sql)    echo "$0: running $f"; sed "1iUSE \`$MYSQL_DATABASE\`;" "$f" | /usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0; echo ;;
			*)        echo "$0: ignoring or entrypoint initdb empty $f" ;;
		esac
		echo
	done

	echo
	echo 'MySQL init process done. Starting mysqld...'
	echo
fi

# Start mysql
/usr/bin/mysqld_safe --user=mysql --datadir='/var/lib/mysql' &
db_process=$!

# Config tor and explorer
TOR_ADDRESS=$(yq e '.tor-address' /root/start9/config.yaml)
mkdir -p /var/lib/tor/hsv3dojo
echo "$TOR_ADDRESS" > /var/lib/tor/hsv3dojo/hostname

if [ "$COMMON_BTC_NETWORK" = "testnet" ]; then
	PAIRING_URL="http://$TOR_ADDRESS/test/v2"
	EXPLORER_ENDPOINT="mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/testnet4"
else
	PAIRING_URL="http://$TOR_ADDRESS/v2"
	EXPLORER_ENDPOINT="mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion"
fi

mkdir -p /var/lib/tor/hsv3explorer
echo -n "$EXPLORER_ENDPOINT" > /var/lib/tor/hsv3explorer/hostname

# Export service properties
cat << EOF > /root/start9/stats.yaml
---
version: 2
data:
  Pairing Code:
    type: string
    value: '{"pairing":{"type":"dojo.api","version":"$DOJO_VERSION_TAG","apikey":"$NODE_API_KEY","url":"$PAIRING_URL"},"explorer":{"type":"explorer.btc_rpc_explorer","url":"http://$EXPLORER_ENDPOINT"}}'
    description: Code for pairing your wallet with this Dojo
    copyable: true
    qr: true
    masked: true
  Admin Key:
    type: string
    value: $(yq e '.admin-key' /root/start9/config.yaml)
    description: Key for accessing the admin/maintenance
    copyable: true
    qr: false
    masked: true
EOF

# Start node
if [ "$COMMON_BTC_NETWORK" = "testnet" ]; then
	cp /home/node/app/static/admin/conf/index-testnet.js /home/node/app/static/admin/conf/index.js
	ln -sf /etc/nginx/sites-available/testnet.conf /etc/nginx/sites-enabled/dojo.conf
else
	cp /home/node/app/static/admin/conf/index-mainnet.js /home/node/app/static/admin/conf/index.js
	ln -sf /etc/nginx/sites-available/mainnet.conf /etc/nginx/sites-enabled/dojo.conf
fi

/home/node/app/wait-for-it.sh 127.0.0.1:3306 --timeout=720 --strict -- pm2-runtime -u node --raw /home/node/app/pm2.config.cjs &
backend_process=$!

# Start nginx
/home/node/app/wait-for-it.sh 127.0.0.1:8080 --timeout=720 --strict -- nginx &
frontend_process=$!

echo 'All processes initalized'

# SIGTERM HANDLING
trap _term SIGTERM

wait -n $db_process $backend_process $frontend_process
