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
    echo "Warning: Soroban onion hostname file not found (announce mode enabled), but basic service is healthy" >&2
    # Don't exit - basic service is working
  else
    # Check if we can reach the onion service through Tor
    ONION_HOSTNAME=$(cat "$SOROBAN_ONION_FILE" 2>/dev/null)
    if [ -z "$ONION_HOSTNAME" ]; then
      echo "Warning: Soroban onion hostname is empty, but basic service is healthy" >&2
      # Don't exit - basic service is working
    else
      # Add .onion suffix if missing
      if [[ "$ONION_HOSTNAME" != *.onion ]]; then
        ONION_HOSTNAME="${ONION_HOSTNAME}.onion"
      fi

      # Try to reach the RPC endpoint through the onion service with shorter timeout
      RPC_API_URL="http://${ONION_HOSTNAME}/rpc"
      SOROBAN_ANNOUNCE_KEY=$([[ "$COMMON_BTC_NETWORK" == "testnet" ]] && echo "$SOROBAN_ANNOUNCE_KEY_TEST" || echo "$SOROBAN_ANNOUNCE_KEY_MAIN")

      # Test SOCKS5 proxy connectivity first
      if ! nc -z localhost 9050 2>/dev/null; then
        echo "Warning: Tor SOCKS5 proxy not accessible, but basic soroban service is healthy" >&2
        # Don't exit - basic service is working
      else
        # Try onion service with much shorter timeout to avoid hanging
        if ! timeout 15 curl -s -f --max-time 10 --retry 1 --retry-delay 2 \
          -X POST -H 'Content-Type: application/json' \
          -d "{ \"jsonrpc\": \"2.0\", \"id\": 42, \"method\":\"directory.List\", \"params\": [{ \"Name\": \"$SOROBAN_ANNOUNCE_KEY\"}] }" \
          --proxy socks5h://localhost:9050 "$RPC_API_URL" > /dev/null 2>&1; then
          echo "Warning: Soroban onion service RPC not responding, but basic service is healthy" >&2
          # Don't exit - basic service is working, onion service might need more time to initialize
        fi
      fi
    fi
  fi
fi

# All checks passed
exit 0
