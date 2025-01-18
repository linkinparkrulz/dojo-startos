#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /usr/local/bin/config.env

mysqladmin --user=$MYSQL_USER --password=$MYSQL_PASSWORD ping -h localhost 2>/dev/null

if [ $? -eq 0 ]; then
  # Online
  exit 0
else
  # Starting
  exit 60
fi
