#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /usr/local/bin/config.env

# Exit early if Soroban is not installed/enabled
if [ "$SOROBAN_INSTALL" != "on" ]; then
  exit 0
fi

# Check if Soroban process is running
if ! pgrep -f "soroban-server" > /dev/null; then
  echo "Soroban process is not running" >&2
  exit 60
fi

# Check if Soroban RPC endpoint is responsive
# Try the main RPC endpoint first, then fallback to basic connectivity check
if ! curl -s -f --max-time 10 "http://${NET_DOJO_SOROBAN_IPV4}:${SOROBAN_PORT}/rpc" > /dev/null 2>&1; then
  # If RPC endpoint fails, check if port is at least listening
  if ! nc -z "${NET_DOJO_SOROBAN_IPV4}" "${SOROBAN_PORT}" 2>/dev/null; then
    echo "Soroban service is not listening on port ${SOROBAN_PORT}" >&2
    exit 61
  fi
fi

# If announce mode is enabled, check if the onion service is working
if [ "$SOROBAN_ANNOUNCE" == "on" ]; then
  # Check if onion hostname file exists
  if [ ! -f "$SOROBAN_ONION_FILE" ]; then
    echo "Soroban onion hostname file not found (announce mode enabled)" >&2
    exit 61
  fi
  
  # Check if we can reach the onion service through Tor
  ONION_HOSTNAME=$(cat "$SOROBAN_ONION_FILE" 2>/dev/null)
  if [ -z "$ONION_HOSTNAME" ]; then
    echo "Soroban onion hostname is empty" >&2
    exit 61
  fi
  
  # Add .onion suffix if missing
  if [[ "$ONION_HOSTNAME" != *.onion ]]; then
    ONION_HOSTNAME="${ONION_HOSTNAME}.onion"
  fi
  
  # Try to reach the RPC endpoint through the onion service
  RPC_API_URL="http://${ONION_HOSTNAME}/rpc"
  SOROBAN_ANNOUNCE_KEY=$([[ "$COMMON_BTC_NETWORK" == "testnet" ]] && echo "$SOROBAN_ANNOUNCE_KEY_TEST" || echo "$SOROBAN_ANNOUNCE_KEY_MAIN")
  
  if ! curl -s -f --max-time 300 --retry 30 --retry-delay 10 \
    -X POST -H 'Content-Type: application/json' \
    -d "{ \"jsonrpc\": \"2.0\", \"id\": 42, \"method\":\"directory.List\", \"params\": [{ \"Name\": \"$SOROBAN_ANNOUNCE_KEY\"}] }" \
    --proxy socks5h://localhost:9050 "$RPC_API_URL" > /dev/null 2>&1; then
    echo "Soroban onion service RPC is not responding properly" >&2
    exit 61
  fi
fi

# All checks passed
exit 0 