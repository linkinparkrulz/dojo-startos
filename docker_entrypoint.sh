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
echo "[i] Reading Dojo Tor address from config..."
TOR_ADDRESS=$(yq e '.tor-address' /root/start9/config.yaml)
echo "[i] Dojo Tor address: $TOR_ADDRESS"
mkdir -p /var/lib/tor/hsv3dojo
echo "$TOR_ADDRESS" > /var/lib/tor/hsv3dojo/hostname

if [ "$COMMON_BTC_NETWORK" = "testnet" ]; then
	PAIRING_URL="http://$TOR_ADDRESS/test/v2"
	EXPLORER_ENDPOINT="mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/testnet4"
	echo "[i] Running on TESTNET"
else
	PAIRING_URL="http://$TOR_ADDRESS/v2"
	EXPLORER_ENDPOINT="mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion"
	echo "[i] Running on MAINNET"
fi

echo "[i] Pairing URL: $PAIRING_URL"

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

# Helper function to log to both stdout and soroban log
log_soroban() {
    echo "$@"
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $@" >> /home/soroban/data/soroban.log
}

# Start Soroban (if enabled) - BEFORE other services
echo "[i] Checking Soroban configuration..."
echo "[i] SOROBAN_INSTALL=$SOROBAN_INSTALL"
echo "[i] SOROBAN_ANNOUNCE=$SOROBAN_ANNOUNCE"

if [ "$SOROBAN_INSTALL" = "on" ]; then
    # Create log directory first with proper permissions
    mkdir -p /home/soroban/data
    chown -R soroban:soroban /home/soroban/data
    chmod -R 755 /home/soroban/data
    
    log_soroban "[ENTRYPOINT] Starting Soroban initialization..."
    log_soroban "[ENTRYPOINT] SOROBAN_INSTALL=$SOROBAN_INSTALL"
    log_soroban "[ENTRYPOINT] SOROBAN_ANNOUNCE=$SOROBAN_ANNOUNCE"
    
    # Determine network-specific configuration
    if [ "$COMMON_BTC_NETWORK" = "testnet" ]; then
        SOROBAN_DOMAIN="$SOROBAN_DOMAIN_TEST"
        SOROBAN_P2P_ROOM="$SOROBAN_P2P_ROOM_TEST"
        SOROBAN_P2P_BOOTSTRAP="$SOROBAN_P2P_BOOTSTRAP_TEST"
        SOROBAN_ANNOUNCE_KEY="$SOROBAN_ANNOUNCE_KEY_TEST"
        log_soroban "[ENTRYPOINT] Using TESTNET Soroban configuration"
    else
        SOROBAN_DOMAIN="$SOROBAN_DOMAIN_MAIN"
        SOROBAN_P2P_ROOM="$SOROBAN_P2P_ROOM_MAIN"
        SOROBAN_P2P_BOOTSTRAP="$SOROBAN_P2P_BOOTSTRAP_MAIN"
        SOROBAN_ANNOUNCE_KEY="$SOROBAN_ANNOUNCE_KEY_MAIN"
        log_soroban "[ENTRYPOINT] Using MAINNET Soroban configuration"
    fi
    
    # Setup Soroban Tor hidden service if announce is enabled
    if [ "$SOROBAN_ANNOUNCE" = "on" ]; then
        log_soroban "[ENTRYPOINT] Soroban announce mode is ENABLED"
        mkdir -p /var/lib/tor/hsv3soroban
        chown -R soroban:soroban /var/lib/tor/hsv3soroban
        
        # Create Tor config for Soroban
        log_soroban "[ENTRYPOINT] Creating Tor configuration for Soroban..."
        cat > /home/soroban/.torrc <<EOF
DataDirectory /var/lib/tor/hsv3soroban
HiddenServiceDir /var/lib/tor/hsv3soroban
HiddenServicePort 80 ${NET_DOJO_SOROBAN_IPV4}:${SOROBAN_PORT}
EOF
        
        chown soroban:soroban /home/soroban/.torrc
        
        # Start Tor for Soroban as the soroban user
        log_soroban "[ENTRYPOINT] Starting Tor for Soroban..."
        # Ensure log file exists with proper permissions
        touch /home/soroban/data/soroban.log
        chown soroban:soroban /home/soroban/data/soroban.log
        chmod 644 /home/soroban/data/soroban.log
        su -s /bin/sh soroban -c "/usr/local/bin/tor -f /home/soroban/.torrc >> /home/soroban/data/soroban.log 2>&1 &"
        
        # Wait for Tor to generate hostname
        log_soroban "[ENTRYPOINT] Waiting for Tor to generate Soroban hidden service..."
        for i in {1..30}; do
            if [ -f /var/lib/tor/hsv3soroban/hostname ]; then
                SOROBAN_ONION=$(cat /var/lib/tor/hsv3soroban/hostname)
                log_soroban "[ENTRYPOINT] ✓ Soroban hidden service ready: $SOROBAN_ONION"
                break
            fi
            sleep 1
        done
        
        if [ ! -f /var/lib/tor/hsv3soroban/hostname ]; then
            log_soroban "[ENTRYPOINT] WARNING: Tor did not generate Soroban hostname file after 30 seconds"
        fi
    else
        log_soroban "[ENTRYPOINT] Soroban announce mode is DISABLED"
    fi
    
    # Start Soroban server
    log_soroban "[ENTRYPOINT] Starting Soroban server as soroban user..."
    log_soroban "[ENTRYPOINT] Soroban will listen on ${NET_DOJO_SOROBAN_IPV4}:${SOROBAN_PORT}"
    
    runuser -u soroban -- /usr/local/bin/start-soroban.sh >> /home/soroban/data/soroban.log 2>&1 &
    soroban_process=$!
    
    log_soroban "[ENTRYPOINT] Soroban started with PID: $soroban_process"
    
    # Wait for Soroban to initialize
    log_soroban "[ENTRYPOINT] Waiting for Soroban to initialize..."
    sleep 5
    
    # Verify Soroban is listening
    if nc -z ${NET_DOJO_SOROBAN_IPV4} ${SOROBAN_PORT} 2>/dev/null; then
        log_soroban "[ENTRYPOINT] ✓ Soroban is listening on port ${SOROBAN_PORT}"
    else
        log_soroban "[ENTRYPOINT] WARNING: Soroban may not be listening on port ${SOROBAN_PORT}"
        log_soroban "[ENTRYPOINT] This may be normal if Soroban is still initializing"
    fi
else
    echo "[i] Soroban is disabled"
    soroban_process=""
fi

# Start node services
/home/node/app/wait-for-it.sh 127.0.0.1:3306 --timeout=720 --strict -- pm2-runtime -u node --raw /home/node/app/pm2.config.cjs &
backend_process=$!

# Start nginx
/home/node/app/wait-for-it.sh 127.0.0.1:8080 --timeout=720 --strict -- nginx &
frontend_process=$!

echo '[i] All processes initialized'

# SIGTERM HANDLING
trap _term SIGTERM

if [ -n "$soroban_process" ]; then
    wait -n $db_process $backend_process $frontend_process $soroban_process
else
    wait -n $db_process $backend_process $frontend_process
fi
