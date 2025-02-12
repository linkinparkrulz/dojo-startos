#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /usr/local/bin/config.env
source /usr/local/bin/functions.sh

admin_key=$(yq -e '.admin-key' /root/start9/config.yaml 2>/dev/null)
access_token=$(cat /run/secrets/access_token 2>/dev/null)

if [ -z "$access_token" ] || ! check_token "$access_token"; then
  access_token=$(do_authenticate "$admin_key")
fi

if [ -z "$access_token" ]; then
  # Starting
  exit 60
fi

if get_pushtx_status "$access_token"; then
  exit 0
fi

echo "Waiting for API to be ready..." >&2
exit 61
