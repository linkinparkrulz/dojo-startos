#!/bin/bash

set -e

# Source config to get admin credentials
source /usr/local/bin/config.env

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
    -d "{\"apikey\":\"$NODE_ADMIN_KEY\"}")

ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.authorizations.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Failed to authenticate with Dojo admin key" >&2
    echo "Auth response: $AUTH_RESPONSE" >&2
    exit 1
fi

# Get list of API keys using Dojo's support API
API_KEYS_RESPONSE=$(curl -s -X GET "http://127.0.0.1:8080/v2/support/apikeys" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

# Parse and format the response
CURRENT_TIME=$(date +%s)
OUTPUT="API Keys:\n\n"

# Check if jq can parse the response
if ! echo "$API_KEYS_RESPONSE" | jq empty 2>/dev/null; then
    echo "Error: Failed to retrieve API keys" >&2
    echo "Response: $API_KEYS_RESPONSE" >&2
    exit 1
fi

# Get count of API keys (response is an array directly)
KEY_COUNT=$(echo "$API_KEYS_RESPONSE" | jq 'length')

if [ "$KEY_COUNT" -eq 0 ]; then
    OUTPUT="No API keys found.\n\nUse 'Generate API Key' action to create one."
else
    # Iterate through API keys
    echo "$API_KEYS_RESPONSE" | jq -r '.[] | "\(.label)|\(.expiresAt)|\(.active)|\(.apikey[0:8])"' | while IFS='|' read -r label expires_at active api_key_preview; do
        EXPIRY_DATE=$(date -d "$expires_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Invalid date")
        EXPIRY_TIMESTAMP=$(date -d "$expires_at" +%s 2>/dev/null || echo "0")
        
        if [ "$active" = "true" ] || [ "$active" = "1" ]; then
            if [ "$EXPIRY_TIMESTAMP" -gt "$CURRENT_TIME" ]; then
                STATUS="✅ Active"
            else
                STATUS="⏰ Expired"
            fi
        else
            STATUS="❌ Inactive"
        fi
        
        OUTPUT="${OUTPUT}• $label\n  Status: $STATUS\n  Expires: $EXPIRY_DATE\n  Key: ${api_key_preview}...\n\n"
    done
fi

# Output in Start9 format
cat << EOF
version: 2
message: |
$(echo -e "$OUTPUT")
value: null
copyable: false
qr: false
EOF
