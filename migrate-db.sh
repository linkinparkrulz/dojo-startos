#!/bin/bash

# Database migration script to ensure api_keys table exists
# This script should be run when the database is already initialized but missing the api_keys table

source /usr/local/bin/config.env

MYSQL_DATABASE=${MYSQL_DATABASE:-"samourai-main"}
MYSQL_USER=${MYSQL_USER:-"samourai"}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-"samourai"}

# Determine the database client binary to use (mysql if present, mariadb otherwise)
if command -v mysql &> /dev/null; then
  DBCLIENT="mysql"
else
  DBCLIENT="mariadb"
fi

echo "[i] Checking if MySQL is running..."
# Wait for MySQL to be ready
for i in {30..0}; do
  if echo "SELECT 1" | "$DBCLIENT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" &> /dev/null; then
    echo "[i] MySQL is ready"
    break
  fi
  echo "[i] MySQL init process in progress..."
  sleep 1
done

if [ "$i" = 0 ]; then
  echo "[!] MySQL failed to start"
  exit 1
fi

echo "[i] Checking if api_keys table exists..."
# Check if api_keys table exists
TABLE_EXISTS=$("$DBCLIENT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SHOW TABLES LIKE 'api_keys';" | wc -l)

if [ "$TABLE_EXISTS" -eq 0 ]; then
  echo "[i] api_keys table does not exist, creating it..."
  
  # Create the api_keys table
  "$DBCLIENT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" << 'EOF'
--
-- Create table "api_keys"
--
CREATE TABLE IF NOT EXISTS `api_keys` (
    `apikeyID`  INT AUTO_INCREMENT PRIMARY KEY,
    `label`     VARCHAR(255) NOT NULL,
    `apikey`    VARCHAR(255) NOT NULL UNIQUE,
    `active`    BOOLEAN NOT NULL DEFAULT TRUE,
    `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expiresAt` TIMESTAMP NOT NULL
);
EOF

  if [ $? -eq 0 ]; then
    echo "[i] Successfully created api_keys table"
  else
    echo "[!] Failed to create api_keys table"
    exit 1
  fi
else
  echo "[i] api_keys table already exists"
fi

echo "[i] Database migration completed successfully"
