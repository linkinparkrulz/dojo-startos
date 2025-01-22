#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /usr/local/bin/config.env

if mysqladmin --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" ping -h localhost 2>/dev/null; then
  # Online
  exit 0
fi

# Starting
exit 60
