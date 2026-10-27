#!/usr/bin/env bash
# BIT WiFi Auto Login / Deauth Script
# Usage: nlogin [-switch [profile] | -ls | --setup | --logout | --status | --keepalive [sec] | --update | --help]
# Setup: run ./setup.sh (or nlogin --setup) to save your credentials

PORTAL="http://172.16.0.200:2280"
RAW_UPDATE_URL="https://raw.githubusercontent.com/ponmudimr/auto-internet-login/main/nlogin.sh"
CRED_DIR="$HOME/.config/bit-wifi"
CREDFILE="$CRED_DIR/credentials"
PROFILES_DIR="$CRED_DIR/profiles"

show_help() {
    cat << 'EOF'
Usage: nlogin [OPTION]

Automates BIT Sathy WiFi captive portal deauthentication, login, and verification.

Options:
  (no option)              Deauthenticate old session, log in, and verify internet
  -s, -switch, --switch [P] Switch to another saved profile (or interactive menu) and log in
  -ls, -l, --list          Show saved profiles count and list all profiles
  -a, --add, --setup       Add a new profile or update saved BIT WiFi credentials
  -d, --logout             Disconnect (deauthenticate) active session without logging in
  -c, --status             Check current internet and captive portal connection status
  -k, --keepalive [SEC]    Monitor connection every SEC seconds (default: 60) and auto-reconnect
  -u, --update             Update nlogin to the latest version from GitHub
  -h, --help               Show this help message and exit

Examples:
  nlogin                   Connect to BIT WiFi with active profile
  nlogin -ls               List all saved profiles and show active profile
  nlogin -switch           Open interactive menu to switch or add a profile
  nlogin -switch 2         Switch directly to profile #2 and log in
  nlogin -switch friend    Switch to profile matching 'friend' and log in
  nlogin --setup           Add or update a BIT WiFi account
  nlogin --logout          Log out active device session
  nlogin --status          Check if internet and portal are reachable
  nlogin --keepalive 30    Auto-reconnect every 30 seconds if connection drops
  nlogin --update          Update nlogin to the latest version
EOF
}

check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ Error: 'curl' is not installed. Please install curl and try again." >&2
        exit 1
    fi
}

prompt_credentials() {
    mkdir -p "$CRED_DIR" "$PROFILES_DIR"
    chmod 700 "$CRED_DIR" "$PROFILES_DIR" 2>/dev/null || true

    sync_active_to_profiles

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

    save_profile_credentials "$input_user" "$input_pass"
    echo "✅ Profile '$input_user' saved and set as active."
}

profile_safe_name() {
    printf '%s' "$1" | tr -c 'a-zA-Z0-9._@-' '_'
}

save_profile_credentials() {
    local user="$1"
    local pass="$2"
    local safe_name
    safe_name="$(profile_safe_name "$user")"
    mkdir -p "$CRED_DIR" "$PROFILES_DIR" 2>/dev/null || true
    (
        umask 077
        printf 'USERNAME=%s\nPASSWORD=%s\n' "$user" "$pass" > "$CREDFILE"
        printf 'USERNAME=%s\nPASSWORD=%s\n' "$user" "$pass" > "$PROFILES_DIR/$safe_name"
    )
    chmod 600 "$CREDFILE" "$PROFILES_DIR/$safe_name" 2>/dev/null || true
}

read_cred_file() {
    local file="$1"
    READ_USER=""
    READ_PASS=""
    if [ -f "$file" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%$'\r'}"
            case "$line" in
                USERNAME=*) READ_USER="${line#USERNAME=}" ;;
                PASSWORD=*) READ_PASS="${line#PASSWORD=}" ;;
            esac
        done < "$file"
        local clean_u
        clean_u="$(strip_surrounding_quotes "$READ_USER")"
        if [ "$clean_u" != "$READ_USER" ]; then
            READ_USER="$clean_u"
            READ_PASS="$(strip_surrounding_quotes "$READ_PASS")"
        fi
    fi
}

sync_active_to_profiles() {
    if [ -f "$CREDFILE" ]; then
        read_cred_file "$CREDFILE"
        if [ -n "$READ_USER" ] && [ -n "$READ_PASS" ]; then
            local safe_name
            safe_name="$(profile_safe_name "$READ_USER")"
            if [ ! -f "$PROFILES_DIR/$safe_name" ]; then
                mkdir -p "$PROFILES_DIR" 2>/dev/null || true
                (
                    umask 077
                    printf 'USERNAME=%s\nPASSWORD=%s\n' "$READ_USER" "$READ_PASS" > "$PROFILES_DIR/$safe_name"
                ) 2>/dev/null || true
                chmod 600 "$PROFILES_DIR/$safe_name" 2>/dev/null || true
            fi
        fi
    fi
}

collect_profiles() {
    sync_active_to_profiles
    load_credentials
    PROFILE_FILES=()
    PROFILE_USERS=()
    if [ -d "$PROFILES_DIR" ]; then
        local f
        for f in "$PROFILES_DIR"/*; do
            [ -f "$f" ] || continue
            read_cred_file "$f"
            if [ -n "$READ_USER" ] && [ -n "$READ_PASS" ]; then
                PROFILE_FILES+=("$f")
                PROFILE_USERS+=("$READ_USER")
            fi
        done
    fi
}

do_list_profiles() {
    collect_profiles
    local count="${#PROFILE_USERS[@]}"
    echo "=== Saved BIT WiFi Profiles ($count) ==="
    if [ "$count" -eq 0 ]; then
        echo "  No saved profiles found. Run 'nlogin --setup' to add one."
        return 0
    fi

    local i
    for ((i = 0; i < count; i++)); do
        local u="${PROFILE_USERS[$i]}"
        if [ "$u" = "$USERNAME" ]; then
            echo "  $((i + 1))) $u (active)"
        else
            echo "  $((i + 1))) $u"
        fi
    done
}

activate_profile_index() {
    local idx="$1"
    local old_user="$USERNAME"
    local old_pass="$PASSWORD"
    local target_file="${PROFILE_FILES[$idx]}"
    read_cred_file "$target_file"
    local new_user="$READ_USER"
    local new_pass="$READ_PASS"

    # If switching away from an active account, deauth the previous account first
    if [ -n "$old_user" ] && [ -n "$old_pass" ] && [ "$old_user" != "$new_user" ]; then
        USERNAME="$old_user"
        PASSWORD="$old_pass"
        do_deauth "[Switch] " >/dev/null 2>&1 || true
    fi

    save_profile_credentials "$new_user" "$new_pass"
    USERNAME="$new_user"
    PASSWORD="$new_pass"
    echo "🔄 Switched active profile to: $USERNAME"
    do_full_login
}

do_switch_profile() {
    local target="${1:-}"
    collect_profiles
    local count="${#PROFILE_USERS[@]}"

    if [ -n "$target" ]; then
        if [[ "$target" =~ ^[0-9]+$ ]] && [ "$target" -ge 1 ] && [ "$target" -le "$count" ]; then
            activate_profile_index $((target - 1))
            return $?
        fi

        local i
        local matched_idx=-1
        for ((i = 0; i < count; i++)); do
            if [ "${PROFILE_USERS[$i]}" = "$target" ]; then
                matched_idx=$i
                break
            fi
        done

        if [ "$matched_idx" -lt 0 ]; then
            local target_lower
            target_lower=$(printf '%s' "$target" | tr '[:upper:]' '[:lower:]')
            for ((i = 0; i < count; i++)); do
                local u_lower
                u_lower=$(printf '%s' "${PROFILE_USERS[$i]}" | tr '[:upper:]' '[:lower:]')
                case "$u_lower" in
                    *"$target_lower"*)
                        matched_idx=$i
                        break
                        ;;
                esac
            done
        fi

        if [ "$matched_idx" -ge 0 ]; then
            activate_profile_index "$matched_idx"
            return $?
        else
            echo "❌ Error: Profile '$target' not found." >&2
            echo "   Run 'nlogin -ls' to see saved profiles, or 'nlogin -switch' to add one." >&2
            return 1
        fi
    fi

    echo "=== Switch BIT WiFi Profile ($count saved) ==="
    local i
    for ((i = 0; i < count; i++)); do
        local u="${PROFILE_USERS[$i]}"
        if [ "$u" = "$USERNAME" ]; then
            echo "  $((i + 1))) $u (active)"
        else
            echo "  $((i + 1))) $u"
        fi
    done
    echo "  n) Add a new profile"
    if [ "$count" -gt 0 ]; then
        echo "  d) Delete a profile"
    fi
    echo "  q) Cancel"
    echo ""

    local choice=""
    read -r -p "Select option: " choice
    case "$choice" in
        [nN]|[aA])
            local prev_user="$USERNAME"
            local prev_pass="$PASSWORD"
            if prompt_credentials; then
                load_credentials
                if [ -n "$prev_user" ] && [ -n "$prev_pass" ] && [ "$prev_user" != "$USERNAME" ]; then
                    local new_u="$USERNAME"
                    local new_p="$PASSWORD"
                    USERNAME="$prev_user"
                    PASSWORD="$prev_pass"
                    do_deauth "[Switch] " >/dev/null 2>&1 || true
                    USERNAME="$new_u"
                    PASSWORD="$new_p"
                fi
                do_full_login
            else
                return 1
            fi
            ;;
        [dD])
            if [ "$count" -eq 0 ]; then
                echo "No profiles to delete."
                return 1
            fi
            local del_idx=""
            read -r -p "Enter profile number to delete [1-$count]: " del_idx
            if [[ "$del_idx" =~ ^[0-9]+$ ]] && [ "$del_idx" -ge 1 ] && [ "$del_idx" -le "$count" ]; then
                local del_user="${PROFILE_USERS[$((del_idx - 1))]}"
                local del_file="${PROFILE_FILES[$((del_idx - 1))]}"
                rm -f "$del_file"
                echo "✅ Deleted profile: $del_user"
                if [ "$del_user" = "$USERNAME" ]; then
                    rm -f "$CREDFILE"
                    collect_profiles
                    if [ "${#PROFILE_FILES[@]}" -gt 0 ]; then
                        read_cred_file "${PROFILE_FILES[0]}"
                        save_profile_credentials "$READ_USER" "$READ_PASS"
                        echo "🔄 Active profile set to: $READ_USER"
                    fi
                fi
            else
                echo "❌ Invalid profile number." >&2
                return 1
            fi
            ;;
        [qQ]|"")
            echo "Cancelled."
            return 0
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                activate_profile_index $((choice - 1))
                return $?
            else
                echo "❌ Invalid choice: $choice" >&2
                return 1
            fi
            ;;
    esac
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
SWITCH_TARGET=""

case "${1:-}" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    -s|-switch|--switch|switch)
        ACTION="switch"
        SWITCH_TARGET="${2:-}"
        ;;
    -ls|--ls|-l|--list|ls|list)
        ACTION="list"
        ;;
    -a|--add|--setup|setup|add)
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

if [ "$ACTION" = "list" ]; then
    do_list_profiles
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

if [ "$ACTION" = "switch" ]; then
    do_switch_profile "$SWITCH_TARGET"
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
