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

strip_surrounding_quotes() {
    local val="$1"
    if [ "${#val}" -ge 2 ]; then
        if [ "${val:0:1}" = '"' ] && [ "${val: -1}" = '"' ]; then
            val="${val:1:${#val}-2}"
        elif [ "${val:0:1}" = "'" ] && [ "${val: -1}" = "'" ]; then
            val="${val:1:${#val}-2}"
        fi
    fi
    printf '%s' "$val"
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

        # Backward compatibility: earlier setup.sh wrapped values in literal quotes
        local clean_user
        clean_user="$(strip_surrounding_quotes "$USERNAME")"
        if [ "$clean_user" != "$USERNAME" ]; then
            USERNAME="$clean_user"
            PASSWORD="$(strip_surrounding_quotes "$PASSWORD")"
        fi
    fi
}

check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ Error: 'curl' is not installed. Please install curl and try again." >&2
        exit 1
    fi
}

check_dependencies

if [ ! -f "$CREDFILE" ]; then
    echo "Credentials not found. Running setup..."
    run_setup
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
DEAUTH_HTTP_CODE=$(printf '%s' "$PASSWORD" | curl -s -w "%{http_code}" --connect-timeout 8 --max-time 15 -X POST "$PORTAL/submit/del_old_user_session.php" \
  --data-urlencode "pcomp=hotspot" \
  --data-urlencode "usrname=$USERNAME" \
  --data-urlencode "newpasswd@-" \
  -o "$TEMP_RESP" 2>/dev/null)
CURL_DEAUTH_EXIT=$?

if [ $CURL_DEAUTH_EXIT -ne 0 ] || [ "$DEAUTH_HTTP_CODE" = "000" ] || [ -z "$DEAUTH_HTTP_CODE" ]; then
    echo "❌ Network Error: Unable to reach BIT WiFi portal at 172.16.0.200:2280." >&2
    echo "   Please make sure you are connected to the BIT WiFi network." >&2
    exit 1
fi

if [ "$DEAUTH_HTTP_CODE" -ne 200 ] 2>/dev/null; then
    echo "❌ Portal Error: Deauth endpoint returned HTTP status $DEAUTH_HTTP_CODE." >&2
    exit 1
fi

DEAUTH_BODY_LOWER=$(tr '[:upper:]' '[:lower:]' < "$TEMP_RESP" 2>/dev/null)
if printf '%s' "$DEAUTH_BODY_LOWER" | grep -qE "invalid|incorrect|authentication failed|access denied|user not found"; then
    echo "❌ Login Rejected: Invalid username or password." >&2
    echo "   Please run setup.sh (or ./setup.sh) to update your credentials." >&2
    exit 2
fi

if printf '%s' "$DEAUTH_BODY_LOWER" | grep -q "deleted 1 old session"; then
    echo "   ↳ Cleared 1 active session."
elif printf '%s' "$DEAUTH_BODY_LOWER" | grep -q "deleted 0 old session"; then
    echo "   ↳ No previous active session found."
fi

sleep 0.3 2>/dev/null || sleep 1

# Step 2: Login current device
echo "[2/3] Logging in as $USERNAME..."
LOGIN_HTTP_CODE=$(printf '%s' "$PASSWORD" | curl -s -w "%{http_code}" --connect-timeout 8 --max-time 15 -X POST "$PORTAL/submit/user_login.php" \
  --data-urlencode "usrname=$USERNAME" \
  --data-urlencode "newpasswd@-" \
  --data-urlencode "terms=on" \
  --data-urlencode "page_sid=internal" \
  --data-urlencode "org_url=http://172.16.0.200/" \
  -o "$TEMP_RESP" 2>/dev/null)
CURL_LOGIN_EXIT=$?

if [ $CURL_LOGIN_EXIT -ne 0 ] || [ "$LOGIN_HTTP_CODE" = "000" ] || [ -z "$LOGIN_HTTP_CODE" ]; then
    echo "❌ Network Error: Portal connection lost during login." >&2
    echo "   Please check your WiFi connection." >&2
    exit 1
fi

if [ "$LOGIN_HTTP_CODE" -ne 200 ] 2>/dev/null; then
    echo "❌ Portal Error: Portal returned HTTP status $LOGIN_HTTP_CODE." >&2
    echo "   The portal server might be down or undergoing maintenance." >&2
    exit 1
fi

LOGIN_BODY=$(cat "$TEMP_RESP" 2>/dev/null)
LOGIN_BODY_LOWER=$(printf '%s' "$LOGIN_BODY" | tr '[:upper:]' '[:lower:]')

if printf '%s' "$LOGIN_BODY_LOWER" | grep -qE "invalid|incorrect|authentication failed|access denied|user not found"; then
    echo "❌ Login Rejected: Invalid username or password." >&2
    echo "   Please run setup.sh (or ./setup.sh) to update your credentials." >&2
    exit 2
fi

if printf '%s' "$LOGIN_BODY_LOWER" | grep -q "hide_popup('error'"; then
    PORTAL_ERR=$(printf '%s' "$LOGIN_BODY" | sed -n "s/.*hide_popup('error','\([^']*\)').*/\1/p" | head -n 1)
    echo "❌ Portal Error: ${PORTAL_ERR:-Login rejected by captive portal.}" >&2
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
