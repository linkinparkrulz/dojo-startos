#!/bin/bash

set -e

# Debug: Show all environment variables that might contain our inputs
echo "Debug: Environment variables:" >&2
env | grep -E "(LABEL|label|EXPIRY|expiry)" >&2 || echo "No matching env vars found" >&2

# Read input from Start9 action environment variables
# Start9 might use different naming conventions, so try multiple variations
LABEL="${LABEL:-${label:-}}"
EXPIRY_DAYS="${EXPIRY_DAYS:-${expiry_days:-${EXPIRY:-365}}}"

# Try Start9's typical input format (often uses the exact field names from input-spec)
# Start9 typically converts kebab-case to SCREAMING_SNAKE_CASE for environment variables
if [ -z "$LABEL" ]; then
    LABEL="${LABEL:-Default}"
fi

if [ -z "$EXPIRY_DAYS" ]; then
    # Try various formats Start9 might use
    EXPIRY_DAYS="${EXPIRY_DAYS:-${EXPIRY_DAYS:-365}}"
fi

# Debug: Show what we found
echo "Debug: After parsing - LABEL='$LABEL', EXPIRY_DAYS='$EXPIRY_DAYS'" >&2

# Final fallback - try command line arguments for manual testing
if [ -z "$LABEL" ] && [ $# -gt 0 ]; then
    LABEL="$1"
    EXPIRY_DAYS="${2:-365}"
    echo "Debug: Using command line args - LABEL='$LABEL', EXPIRY_DAYS='$EXPIRY_DAYS'" >&2
fi

# Validate inputs
if [ -z "$LABEL" ]; then
    echo "Error: API key label is required" >&2
    exit 1
fi

# Get admin key from Start9 configuration
ADMIN_KEY=$(yq e '.admin-key' /root/start9/config.yaml)
if [ -z "$ADMIN_KEY" ]; then
    echo "Error: Admin key not found in Start9 configuration" >&2
    exit 1
fi

# Wait for Dojo to be ready
echo "Waiting for Dojo API to be ready..."
for i in {1..30}; do
    if curl -s -f "http://127.0.0.1:8080/v2/auth/login" > /dev/null 2>&1; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: Dojo API is not responding after 30 attempts" >&2
        exit 1
    fi
    sleep 2
done

# Get admin JWT token
AUTH_RESPONSE=$(curl -s -X POST "http://127.0.0.1:8080/v2/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$ADMIN_KEY\"}")

ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.authorizations.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Failed to authenticate with Dojo admin key" >&2
    echo "Auth response: $AUTH_RESPONSE" >&2
    exit 1
fi

# Calculate expiry date (ISO format as expected by Dojo API)
EXPIRY_DATE=$(date -d "+${EXPIRY_DAYS} days" -Iseconds)

# Create new API key using Dojo's support API
API_KEY_RESPONSE=$(curl -s -X POST "http://127.0.0.1:8080/v2/support/apikey" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "{\"label\":\"$LABEL\",\"expiresAt\":\"$EXPIRY_DATE\"}")

# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create API key - curl request failed" >&2
    exit 1
fi

# Get the newly created API key by listing all keys and finding the one with our label
API_KEYS_RESPONSE=$(curl -s -X GET "http://127.0.0.1:8080/v2/support/apikeys" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

NEW_API_KEY=$(echo "$API_KEYS_RESPONSE" | jq -r --arg label "$LABEL" '.[] | select(.label == $label) | .apikey' | tail -1)
FORMATTED_EXPIRY_DATE=$(date -d "$EXPIRY_DATE" "+%Y-%m-%d %H:%M:%S")

if [ -z "$NEW_API_KEY" ] || [ "$NEW_API_KEY" = "null" ]; then
    echo "Error: Failed to generate API key" >&2
    echo "API Key Response: $API_KEY_RESPONSE" >&2
    echo "API Keys List Response: $API_KEYS_RESPONSE" >&2
    exit 1
fi

# Get Dojo Tor address for pairing URL
TOR_ADDRESS=$(yq e '.tor-address' /root/start9/config.yaml)

# Determine network from Start9 config (check if using testnet bitcoind)
BITCOIN_NODE_TYPE=$(yq e '.bitcoin-node.type' /root/start9/config.yaml)
if [ "$BITCOIN_NODE_TYPE" = "bitcoind-testnet" ]; then
    PAIRING_URL="http://$TOR_ADDRESS/test/v2"
else
    PAIRING_URL="http://$TOR_ADDRESS/v2"
fi

# Output the result in Start9 format
cat << EOF
version: 2
message: |
  API Key Generated Successfully!
  
  Label: $LABEL
  Expires: $FORMATTED_EXPIRY_DATE
  
  🔑 API Key:
  $NEW_API_KEY
  
  📱 Pairing Code (for wallets):
  {"pairing":{"type":"dojo.api","version":"1.28.0","apikey":"$NEW_API_KEY","url":"$PAIRING_URL"}}
  
  ⚠️ IMPORTANT: Save this API key now - it cannot be retrieved later!
value: |
  API Key: $NEW_API_KEY
  Pairing URL: $PAIRING_URL
  Expires: $FORMATTED_EXPIRY_DATE
copyable: true
qr: false
EOF
