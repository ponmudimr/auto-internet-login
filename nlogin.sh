#!/usr/bin/env bash
# BIT WiFi Auto Login / Deauth Script
# Usage: nlogin [--setup | --logout | --status | --keepalive [sec] | --update | --help]
# Setup: run ./setup.sh (or nlogin --setup) to save your credentials

PORTAL="http://172.16.0.200:2280"
RAW_UPDATE_URL="https://raw.githubusercontent.com/ponmudimr/auto-internet-login/main/nlogin.sh"
CRED_DIR="$HOME/.config/bit-wifi"
CREDFILE="$CRED_DIR/credentials"

show_help() {
    cat << 'EOF'
Usage: nlogin [OPTION]

Automates BIT Sathy WiFi captive portal deauthentication, login, and verification.

Options:
  (no option)            Deauthenticate old session, log in, and verify internet
  -s, --setup            Configure or update your BIT WiFi credentials
  -d, --logout           Disconnect (deauthenticate) active session without logging in
  -c, --status           Check current internet and captive portal connection status
  -k, --keepalive [SEC]  Monitor connection every SEC seconds (default: 60) and auto-reconnect
  -u, --update           Update nlogin to the latest version from GitHub
  -h, --help             Show this help message and exit

Examples:
  nlogin                 Connect to BIT WiFi
  nlogin --setup         Update saved username and password
  nlogin --logout        Log out active device session
  nlogin --status        Check if internet and portal are reachable
  nlogin --keepalive 30  Auto-reconnect every 30 seconds if connection drops
  nlogin --update        Update nlogin to the latest version
EOF
}

check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ Error: 'curl' is not installed. Please install curl and try again." >&2
        exit 1
    fi
}

prompt_credentials() {
    mkdir -p "$CRED_DIR"
    chmod 700 "$CRED_DIR" 2>/dev/null || true

    echo "=== BIT WiFi Credential Setup ==="
    echo ""
    local input_user=""
    local input_pass=""
    read -r -p "Enter your BIT WiFi username (e.g. yourname.ec25@bitsathy.ac.in): " input_user
    read -r -s -p "Enter your BIT WiFi password: " input_pass
    echo ""
    echo ""

    if [ -z "$input_user" ] || [ -z "$input_pass" ]; then
        echo "❌ Error: Username and password cannot be empty." >&2
        return 1
    fi

    (
        umask 077
        printf 'USERNAME=%s\nPASSWORD=%s\n' "$input_user" "$input_pass" > "$CREDFILE"
    )
    chmod 600 "$CREDFILE" 2>/dev/null || true
    echo "✅ Credentials saved securely at ~/.config/bit-wifi/credentials"
}

run_setup() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$script_dir/setup.sh" ]; then
        "$script_dir/setup.sh"
    else
        prompt_credentials
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

ensure_credentials() {
    load_credentials
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        echo "Credentials missing or incomplete. Running setup..."
        if ! run_setup; then
            echo "❌ Error: Setup incomplete. Exiting." >&2
            exit 1
        fi
        load_credentials
    fi

    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        echo "❌ Error: Setup incomplete. Exiting." >&2
        exit 1
    fi
}

verify_internet() {
    local code
    code=$(curl -s --connect-timeout 3 --max-time 5 -o /dev/null -w "%{http_code}" "http://connectivitycheck.gstatic.com/generate_204" 2>/dev/null)
    if [ "$code" = "204" ]; then
        return 0
    fi

    code=$(curl -s --connect-timeout 3 --max-time 5 -o /dev/null -w "%{http_code}" "http://cp.cloudflare.com/generate_204" 2>/dev/null)
    if [ "$code" = "204" ]; then
        return 0
    fi

    local body_file="${TEMP_RESP:-/tmp/bit_wifi_verify_$$}"
    code=$(curl -s --connect-timeout 3 --max-time 5 -w "%{http_code}" "http://neverssl.com/" -o "$body_file" 2>/dev/null)
    if [ "$code" = "200" ] && grep -qi "neverssl" "$body_file" 2>/dev/null; then
        return 0
    fi

    LAST_VERIFY_CODE="${code:-none}"
    return 1
}

do_deauth() {
    local step_prefix="$1"
    echo "${step_prefix}Deauthenticating old session for $USERNAME..."

    local deauth_http_code
    deauth_http_code=$(printf '%s' "$PASSWORD" | curl -s -w "%{http_code}" --connect-timeout 8 --max-time 15 -X POST "$PORTAL/submit/del_old_user_session.php" \
        --data-urlencode "pcomp=hotspot" \
        --data-urlencode "usrname=$USERNAME" \
        --data-urlencode "newpasswd@-" \
        -o "$TEMP_RESP" 2>/dev/null)
    local curl_exit=$?

    if [ $curl_exit -ne 0 ] || [ "$deauth_http_code" = "000" ] || [ -z "$deauth_http_code" ]; then
        echo "❌ Network Error: Unable to reach BIT WiFi portal at 172.16.0.200:2280." >&2
        echo "   Please make sure you are connected to the BIT WiFi network." >&2
        return 1
    fi

    if [ "$deauth_http_code" -ne 200 ] 2>/dev/null; then
        echo "❌ Portal Error: Deauth endpoint returned HTTP status $deauth_http_code." >&2
        return 1
    fi

    local deauth_body_lower
    deauth_body_lower=$(tr '[:upper:]' '[:lower:]' < "$TEMP_RESP" 2>/dev/null)

    if printf '%s' "$deauth_body_lower" | grep -qE "invalid|incorrect|authentication failed|access denied|user not found"; then
        echo "❌ Login Rejected: Invalid username or password." >&2
        echo "   Please run 'nlogin --setup' (or ./setup.sh) to update your credentials." >&2
        return 2
    fi

    if printf '%s' "$deauth_body_lower" | grep -q "deleted 1 old session"; then
        echo "   ↳ Cleared 1 active session."
    elif printf '%s' "$deauth_body_lower" | grep -q "deleted 0 old session"; then
        echo "   ↳ No previous active session found."
    fi
    return 0
}

do_login() {
    local step_prefix="$1"
    echo "${step_prefix}Logging in as $USERNAME..."

    local login_http_code
    login_http_code=$(printf '%s' "$PASSWORD" | curl -s -w "%{http_code}" --connect-timeout 8 --max-time 15 -X POST "$PORTAL/submit/user_login.php" \
        --data-urlencode "usrname=$USERNAME" \
        --data-urlencode "newpasswd@-" \
        --data-urlencode "terms=on" \
        --data-urlencode "page_sid=internal" \
        --data-urlencode "org_url=http://172.16.0.200/" \
        -o "$TEMP_RESP" 2>/dev/null)
    local curl_exit=$?

    if [ $curl_exit -ne 0 ] || [ "$login_http_code" = "000" ] || [ -z "$login_http_code" ]; then
        echo "❌ Network Error: Portal connection lost during login." >&2
        echo "   Please check your WiFi connection." >&2
        return 1
    fi

    if [ "$login_http_code" -ne 200 ] 2>/dev/null; then
        echo "❌ Portal Error: Portal returned HTTP status $login_http_code." >&2
        echo "   The portal server might be down or undergoing maintenance." >&2
        return 1
    fi

    local login_body
    login_body=$(cat "$TEMP_RESP" 2>/dev/null)
    local login_body_lower
    login_body_lower=$(printf '%s' "$login_body" | tr '[:upper:]' '[:lower:]')

    if printf '%s' "$login_body_lower" | grep -qE "invalid|incorrect|authentication failed|access denied|user not found"; then
        echo "❌ Login Rejected: Invalid username or password." >&2
        echo "   Please run 'nlogin --setup' (or ./setup.sh) to update your credentials." >&2
        return 2
    fi

    if printf '%s' "$login_body_lower" | grep -q "hide_popup('error'"; then
        local portal_err
        portal_err=$(printf '%s' "$login_body" | sed -n "s/.*hide_popup('error','\([^']*\)').*/\1/p" | head -n 1)
        echo "❌ Portal Error: ${portal_err:-Login rejected by captive portal.}" >&2
        return 1
    fi

    return 0
}

do_status() {
    echo "=== BIT WiFi Connection Status ==="
    local portal_code
    portal_code=$(curl -s --connect-timeout 3 --max-time 5 -o /dev/null -w "%{http_code}" "$PORTAL/cportal/login.html" 2>/dev/null)
    if [ -n "$portal_code" ] && [ "$portal_code" != "000" ]; then
        echo "📡 BIT WiFi Portal ($PORTAL): Reachable (HTTP $portal_code)"
    else
        echo "📡 BIT WiFi Portal ($PORTAL): Unreachable (not on BIT WiFi?)"
    fi

    if verify_internet; then
        echo "🌐 Internet Status: Connected ✅"
        return 0
    else
        echo "🌐 Internet Status: Offline / Captive Portal Blocked ❌"
        return 1
    fi
}

do_full_login() {
    echo "Connecting to BIT WiFi portal..."

    do_deauth "[1/3] " || exit $?

    sleep 0.3 2>/dev/null || sleep 1

    do_login "[2/3] " || exit $?

    echo "[3/3] Verifying internet connection..."
    if verify_internet; then
        echo "🎉 Success! Connected to the internet."
        return 0
    else
        echo "⚠️ Warning: Login submitted, but internet verification check failed (HTTP status: ${LAST_VERIFY_CODE:-none})."
        echo "   Your account may have hit its data/session limit or the portal may require manual verification."
        return 1
    fi
}

do_keepalive() {
    local interval="${1:-60}"
    if ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt 5 ]; then
        interval=60
    fi
    echo "🔄 Keep-alive mode started (checking every ${interval}s). Press Ctrl+C to stop."
    while true; do
        if ! verify_internet; then
            echo "[$(date '+%H:%M:%S')] ⚠️ Connection dropped. Reconnecting..."
            do_full_login || true
        fi
        sleep "$interval"
    done
}

do_update() {
    echo "Checking for updates from GitHub..."
    local http_code
    http_code=$(curl -fsSL -w "%{http_code}" --connect-timeout 8 --max-time 15 "$RAW_UPDATE_URL" -o "$TEMP_RESP" 2>/dev/null)
    if [ "$http_code" != "200" ] || ! head -n 1 "$TEMP_RESP" 2>/dev/null | grep -q "^#!/"; then
        echo "❌ Update Failed: Could not download latest version from GitHub." >&2
        echo "   Please make sure you are connected to the internet first (run 'nlogin')." >&2
        return 1
    fi

    local install_dir="$HOME/.local/bin"
    if [ -n "${PREFIX:-}" ] && [ -d "$PREFIX/bin" ] && [ -w "$PREFIX/bin" ]; then
        install_dir="$PREFIX/bin"
    fi
    mkdir -p "$install_dir" 2>/dev/null || true

    if cp "$TEMP_RESP" "$install_dir/nlogin" 2>/dev/null && chmod +x "$install_dir/nlogin" 2>/dev/null; then
        echo "✅ Updated successfully! Latest version installed at $install_dir/nlogin"
        return 0
    else
        echo "❌ Update Failed: Could not write to $install_dir/nlogin" >&2
        return 1
    fi
}

# Parse CLI flags
ACTION="login"
KEEPALIVE_INTERVAL=60

case "${1:-}" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    -s|--setup|setup)
        ACTION="setup"
        ;;
    -d|--logout|logout)
        ACTION="logout"
        ;;
    -c|--status|status)
        ACTION="status"
        ;;
    -k|--keepalive|keepalive)
        ACTION="keepalive"
        KEEPALIVE_INTERVAL="${2:-60}"
        ;;
    -u|--update|update)
        ACTION="update"
        ;;
    "")
        ACTION="login"
        ;;
    *)
        echo "❌ Unknown option: $1" >&2
        echo "Run 'nlogin --help' for usage information." >&2
        exit 1
        ;;
esac

check_dependencies

if [ "$ACTION" = "setup" ]; then
    prompt_credentials
    exit $?
fi

TEMP_RESP=$(mktemp 2>/dev/null || echo "/tmp/bit_wifi_resp_$$")
cleanup() {
    rm -f "$TEMP_RESP"
}
trap cleanup EXIT

if [ "$ACTION" = "status" ]; then
    do_status
    exit $?
fi

if [ "$ACTION" = "update" ]; then
    do_update
    exit $?
fi

ensure_credentials

case "$ACTION" in
    logout)
        if do_deauth ""; then
            echo "✅ Session disconnected (logged out)."
        else
            exit $?
        fi
        ;;
    keepalive)
        do_keepalive "$KEEPALIVE_INTERVAL"
        ;;
    login)
        do_full_login
        ;;
esac
