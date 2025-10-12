#!/bin/bash
set -ea

_term() {
  echo "Caught SIGTERM signal!"
  kill -TERM "$backend_process" 2>/dev/null
  kill -TERM "$db_process" 2>/dev/null
  kill -TERM "$frontend_process" 2>/dev/null
  kill -TERM "$soroban_process" 2>/dev/null
}

source /usr/local/bin/config.env

# DATABASE SETUP
if [ -d "/run/mysqld" ]; then
	# mysqld run directory already present, no need to create
	chown -R mysql:mysql /run/mysqld
else
	echo "[i] MySQL run directory not found, creating...."
	mkdir -p /run/mysqld
	chown -R mysql:mysql /run/mysqld
fi

MYSQL_DATABASE=${MYSQL_DATABASE:-"samourai-main"}
MYSQL_USER=${MYSQL_USER:-"samourai"}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-"samourai"}

if [ ! -f /var/lib/mysql/.dojo_db_initialized ]; then
    echo "[i] MySQL data directory not found or not initialized, creating initial DBs"

    mkdir -p /var/lib/mysql
    chown -R mysql:mysql /var/lib/mysql
    touch /var/lib/mysql/.dojo_db_initialized

    mysql_install_db --user=mysql --ldata=/var/lib/mysql > /dev/null

    if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
        MYSQL_ROOT_PASSWORD=$(pwgen 16 1)
        echo "[i] MySQL root Password: $MYSQL_ROOT_PASSWORD"
        export MYSQL_ROOT_PASSWORD
    fi

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
    echo
    echo 'MySQL init process done. Starting mysqld...'
    echo

    # Run initial SQL scripts
    sed "1iUSE \`$MYSQL_DATABASE\`;" /docker-entrypoint-initdb.d/2_update.sql | /usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0

    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sql)    echo "$0: running $f"; sed "1iUSE \`$MYSQL_DATABASE\`;" "$f" | /usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0; echo ;;
            *)        echo "$0: ignoring or entrypoint initdb empty $f" ;;
        esac
        echo
    done

    touch /var/lib/mysql/.dojo_db_initialized
else
    echo "[i] MySQL data directory already initialized, skipping initial DB creation."
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

# Set dojo config corresponding to current network
if [ "$COMMON_BTC_NETWORK" = "testnet" ]; then
	cp /home/node/app/static/admin/conf/index-testnet.js /home/node/app/static/admin/conf/index.js
	ln -sf /etc/nginx/sites-available/testnet.conf /etc/nginx/sites-enabled/dojo.conf
else
	cp /home/node/app/static/admin/conf/index-mainnet.js /home/node/app/static/admin/conf/index.js
	ln -sf /etc/nginx/sites-available/mainnet.conf /etc/nginx/sites-enabled/dojo.conf
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

# Start Soroban (if enabled)
if [ "$SOROBAN_INSTALL" = "on" ]; then
    echo "[i] Starting Soroban..."
    
    # Determine network-specific configuration
    if [ "$COMMON_BTC_NETWORK" = "testnet" ]; then
        SOROBAN_DOMAIN="$SOROBAN_DOMAIN_TEST"
        SOROBAN_P2P_ROOM="$SOROBAN_P2P_ROOM_TEST"
        SOROBAN_P2P_BOOTSTRAP="$SOROBAN_P2P_BOOTSTRAP_TEST"
        SOROBAN_ANNOUNCE_KEY="$SOROBAN_ANNOUNCE_KEY_TEST"
    else
        SOROBAN_DOMAIN="$SOROBAN_DOMAIN_MAIN"
        SOROBAN_P2P_ROOM="$SOROBAN_P2P_ROOM_MAIN"
        SOROBAN_P2P_BOOTSTRAP="$SOROBAN_P2P_BOOTSTRAP_MAIN"
        SOROBAN_ANNOUNCE_KEY="$SOROBAN_ANNOUNCE_KEY_MAIN"
    fi
    
    # Create Soroban directories
    mkdir -p /home/soroban/data
    chown -R soroban:soroban /home/soroban/data
    
    # Setup Soroban Tor hidden service if announce is enabled
    if [ "$SOROBAN_ANNOUNCE" = "on" ]; then
        mkdir -p /var/lib/tor/hsv3soroban
        chown -R soroban:soroban /var/lib/tor/hsv3soroban
        
        # Create Tor config for Soroban
        cat > /home/soroban/.torrc <<EOF
DataDirectory /var/lib/tor/hsv3soroban
HiddenServiceDir /var/lib/tor/hsv3soroban
HiddenServicePort 80 ${NET_DOJO_SOROBAN_IPV4}:${SOROBAN_PORT}
EOF
        
        chown soroban:soroban /home/soroban/.torrc
        
        # Start Tor for Soroban as the soroban user
        su -s /bin/sh soroban -c "tor -f /home/soroban/.torrc > /home/soroban/data/tor.log 2>&1 &"
        
        # Wait for Tor to generate hostname
        echo "[i] Waiting for Tor to generate Soroban hidden service..."
        for i in {1..30}; do
            if [ -f /var/lib/tor/hsv3soroban/hostname ]; then
                echo "[i] Soroban hidden service ready: $(cat /var/lib/tor/hsv3soroban/hostname)"
                break
            fi
            sleep 1
        done
    fi
    
    # Start Soroban server as the soroban user
    SOROBAN_CMD="soroban-server \
        --hostname=${NET_DOJO_SOROBAN_IPV4} \
        --port=${SOROBAN_PORT} \
        --log=${SOROBAN_LOG_LEVEL}"
    
    # Add P2P configuration
    if [ -n "$SOROBAN_P2P_BOOTSTRAP" ]; then
        SOROBAN_CMD="$SOROBAN_CMD \
            --p2pListenPort=${SOROBAN_P2P_LISTEN_PORT} \
            --p2pRoom=${SOROBAN_P2P_ROOM} \
            --p2pBootstrap=${SOROBAN_P2P_BOOTSTRAP}"
    fi
    
    # Add Tor configuration if announce is enabled
    if [ "$SOROBAN_ANNOUNCE" = "on" ]; then
        SOROBAN_CMD="$SOROBAN_CMD --withTor=true"
    fi
    
    # Start Soroban
    su -s /bin/sh soroban -c "$SOROBAN_CMD > /home/soroban/data/soroban.log 2>&1 &"
    soroban_process=$!
    
    echo "[i] Soroban started with PID $soroban_process"
    
    # Wait a moment for Soroban to initialize
    sleep 2
    
    # Verify Soroban is listening
    if nc -z ${NET_DOJO_SOROBAN_IPV4} ${SOROBAN_PORT} 2>/dev/null; then
        echo "[i] Soroban is listening on port ${SOROBAN_PORT}"
    else
        echo "[!] Warning: Soroban may not be listening on port ${SOROBAN_PORT}"
        echo "[!] Check logs at /home/soroban/data/soroban.log"
    fi
fi

# Start node services
/home/node/app/wait-for-it.sh 127.0.0.1:3306 --timeout=720 --strict -- pm2-runtime -u node --raw /home/node/app/pm2.config.cjs &
backend_process=$!

# Start nginx
/home/node/app/wait-for-it.sh 127.0.0.1:8080 --timeout=720 --strict -- nginx &
frontend_process=$!

echo 'All processes initialized'

# SIGTERM HANDLING
trap _term SIGTERM

wait -n $db_process $backend_process $frontend_process $soroban_process
