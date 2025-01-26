#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /usr/local/bin/config.env
source /usr/local/bin/functions.sh

bci_result=$(curl -sS --user "$BITCOIND_RPC_USER:$BITCOIND_RPC_PASSWORD" --data-binary '{"jsonrpc": "1.0", "id": "gbci", "method": "getblockchaininfo", "params": []}' -H 'content-type: text/plain;' http://$BITCOIND_IP:$BITCOIND_RPC_PORT/ 2>&1)
bci_return=$?
bci_error=$(echo "$bci_result" | yq -e '.message' 2>/dev/null)

if [[ $bci_return -ne 0 ]]; then
  echo "Error contacting Bitcoin RPC: $bci_result" >&2
  exit 61
elif [ "$bci_error" != "null" ]; then
  echo "Bitcoin RPC returned error: $bci_error" >&2
  exit 61
fi

bci_block_count=$(echo "$bci_result" | yq -e '.result.blocks' 2>/dev/null)
bci_block_ibd=$(echo "$bci_result" | yq -e '.result.initialblockdownload' 2>/dev/null)
if [ "$bci_block_count" = "null" ]; then
  echo "Error ascertaining Bitcoin blockchain status: $bci_error" >&2
  exit 61
elif [ "$bci_block_ibd" != "false" ] ; then
  bci_block_headers=$(echo "$bci_result" | yq -e '.result.headers' 2>/dev/null)
  echo -n "Bitcoin blockchain is not fully synced yet: $bci_block_count downloaded of $bci_block_headers blocks" >&2
  echo " ($(expr ${bci_block_count}00 / $bci_block_headers)%)" >&2
  exit 61
fi

admin_key=$(yq -e '.admin-key' /root/start9/config.yaml 2>/dev/null)
access_token=$(cat /run/secrets/access_token 2>/dev/null)

if [ -z "$access_token" ] || ! check_token "$access_token"; then
  access_token=$(do_authenticate "$admin_key")
fi

if [ -z "$access_token" ]; then
  # Starting
  exit 60
fi

account_status=$(get_account_status "$access_token")
pushtx_status=$(get_pushtx_status "$access_token")
synced_blocks=$(echo "$account_status" | yq -e '.blocks' 2>/dev/null)
bitcoind_blocks=$(echo "$pushtx_status" | yq -e '.data.bitcoind.blocks' 2>/dev/null)
if [[ $synced_blocks -eq $bitcoind_blocks ]]; then
  exit 0
else
  sync_progress=$(printf "%.0f" "$(bc -l <<<"$synced_blocks / $bitcoind_blocks * 100")")
  echo "Syncing - $sync_progress% (Block #$synced_blocks)" >&2
  exit 61
fi
