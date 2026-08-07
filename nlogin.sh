#!/bin/bash
# BIT WiFi Auto Login/Deauth Script
# Usage: ./nlogin.sh
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
        echo "Run setup.sh first to configure credentials."
        exit 1
    fi
}

if [ ! -f "$CREDFILE" ]; then
    echo "Credentials not found. Running setup..."
    run_setup
fi

source "$CREDFILE" 2>/dev/null

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Credentials missing or invalid. Running setup..."
    run_setup
    source "$CREDFILE" 2>/dev/null
fi

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Setup incomplete. Exiting."
    exit 1
fi

do_deauth() {
    echo "Deauthenticating old session..."
    curl -s --connect-timeout 10 -X POST "$PORTAL/submit/del_old_user_session.php" \
      --data-urlencode "pcomp=hotspot" \
      --data-urlencode "usrname=$USERNAME" \
      --data-urlencode "newpasswd=$PASSWORD" \
      -o /tmp/deauth_response.html
    echo "Deauth sent at $(date)"
}

do_login() {
    echo "Logging in as $USERNAME ..."
    curl -s --connect-timeout 10 -X POST "$PORTAL/submit/user_login.php" \
      --data-urlencode "usrname=$USERNAME" \
      --data-urlencode "newpasswd=$PASSWORD" \
      --data-urlencode "terms=on" \
      --data-urlencode "page_sid=internal" \
      --data-urlencode "org_url=http://172.16.0.200/" \
      -o /tmp/nlogin_response.html
    echo "Login attempt sent at $(date)"
}

do_deauth
sleep 2
do_login

if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" http://neverssl.com/ | grep -q "200"; then
    echo "Connected to the internet."
else
    echo "Still not connected — check the portal manually."
fi
