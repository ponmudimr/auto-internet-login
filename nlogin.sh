#!/usr/bin/env bash
# BIT WiFi Auto Login/Deauth Script
# Usage: nlogin (or ./nlogin.sh)
# Setup: run ./setup.sh first to save your credentials

PORTAL="http://172.16.0.200:2280"
CREDFILE="$HOME/.config/bit-wifi/credentials"

run_setup() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/setup.sh" ]; then
        "$SCRIPT_DIR/setup.sh"
    elif command -v setup.sh >/dev/null 2>&1; then
        setup.sh
    else
        echo "Error: setup.sh not found. Please run setup.sh first."
        exit 1
    fi
}

load_credentials() {
    USERNAME=""
    PASSWORD=""
    if [ -f "$CREDFILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%$'\r'}"
            case "$line" in
                USERNAME=*) USERNAME="${line#USERNAME=}" ;;
                PASSWORD=*) PASSWORD="${line#PASSWORD=}" ;;
            esac
        done < "$CREDFILE"
    fi
}

if [ ! -f "$CREDFILE" ]; then
    echo "Credentials not found. Running setup..."
    run_setup
    load_credentials
fi

load_credentials

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Credentials missing or incomplete. Running setup..."
    run_setup
    load_credentials
fi

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Error: Setup incomplete. Exiting."
    exit 1
fi

TEMP_RESP=$(mktemp 2>/dev/null || echo "/tmp/bit_wifi_resp_$$")
cleanup() {
    rm -f "$TEMP_RESP"
}
trap cleanup EXIT

echo "Connecting to BIT WiFi portal..."

# Step 1: Deauthenticate previous active session
echo "[1/3] Deauthenticating old session for $USERNAME..."
DEAUTH_HTTP_CODE=$(curl -s -w "%{http_code}" --connect-timeout 10 -X POST "$PORTAL/submit/del_old_user_session.php" \
  --data-urlencode "pcomp=hotspot" \
  --data-urlencode "usrname=$USERNAME" \
  --data-urlencode "newpasswd=$PASSWORD" \
  -o "$TEMP_RESP" 2>/dev/null)
CURL_DEAUTH_EXIT=$?

if [ $CURL_DEAUTH_EXIT -ne 0 ] || [ "$DEAUTH_HTTP_CODE" = "000" ] || [ -z "$DEAUTH_HTTP_CODE" ]; then
    echo "❌ Network Error: Unable to reach BIT WiFi portal at 172.16.0.200:2280."
    echo "   Please make sure you are connected to the BIT WiFi network."
    exit 1
fi

sleep 1

# Step 2: Login current device
echo "[2/3] Logging in as $USERNAME..."
LOGIN_HTTP_CODE=$(curl -s -w "%{http_code}" --connect-timeout 10 -X POST "$PORTAL/submit/user_login.php" \
  --data-urlencode "usrname=$USERNAME" \
  --data-urlencode "newpasswd=$PASSWORD" \
  --data-urlencode "terms=on" \
  --data-urlencode "page_sid=internal" \
  --data-urlencode "org_url=http://172.16.0.200/" \
  -o "$TEMP_RESP" 2>/dev/null)
CURL_LOGIN_EXIT=$?

if [ $CURL_LOGIN_EXIT -ne 0 ] || [ "$LOGIN_HTTP_CODE" = "000" ] || [ -z "$LOGIN_HTTP_CODE" ]; then
    echo "❌ Network Error: Portal connection lost during login."
    echo "   Please check your WiFi connection."
    exit 1
fi

if [ "$LOGIN_HTTP_CODE" -ne 200 ] 2>/dev/null; then
    echo "❌ Portal Error: Portal returned HTTP status $LOGIN_HTTP_CODE."
    echo "   The portal server might be down or undergoing maintenance."
    exit 1
fi

LOGIN_BODY=$(cat "$TEMP_RESP" 2>/dev/null)
LOGIN_BODY_LOWER=$(echo "$LOGIN_BODY" | tr '[:upper:]' '[:lower:]')

if echo "$LOGIN_BODY_LOWER" | grep -qE "invalid|incorrect|authentication failed|access denied|user not found"; then
    echo "❌ Login Rejected: Invalid username or password."
    echo "   Please run setup.sh (or ./setup.sh) to update your credentials."
    exit 1
fi

# Step 3: Verify Internet Connectivity
echo "[3/3] Verifying internet connection..."
VERIFY_CODE=$(curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" http://neverssl.com/ 2>/dev/null)

if [ "$VERIFY_CODE" = "200" ] || [ "$VERIFY_CODE" = "301" ] || [ "$VERIFY_CODE" = "302" ]; then
    echo "🎉 Success! Connected to the internet."
else
    echo "⚠️ Warning: Login submitted, but internet verification check failed (HTTP status: ${VERIFY_CODE:-none})."
    echo "   Your account may have hit its data/session limit or the portal may require manual verification."
fi
