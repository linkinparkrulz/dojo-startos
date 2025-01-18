#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /usr/local/bin/config.env
source /usr/local/bin/functions.sh

admin_key=$(yq -e '.admin-key' /root/start9/config.yaml 2>/dev/null)
access_token=$(cat /run/secrets/access_token 2>/dev/null)

if [[ $? -ne 0 ]] || [[ $(check_token "$access_token") -ne 0 ]]; then
  access_token=$(do_authenticate "$admin_key")
fi

if [ $? -eq 0 ]; then
  get_pushtx_status "$access_token"
  if [[ $? -eq 0 ]]; then
    exit 0
  else
    echo "Waiting for PushTx API to be ready..." >&2
    exit 61
  fi
else
  # Starting
  exit 60
fi
