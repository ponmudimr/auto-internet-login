#!/bin/bash
# BIT WiFi Auto Login/Deauth Script
# Usage: ./nlogin.sh
# Setup: run ./setup.sh first to save your credentials

PORTAL="http://172.16.0.200:2280"
CREDFILE="$HOME/.config/bit-wifi/credentials"

if [ ! -f "$CREDFILE" ]; then
    echo "Credentials not found."
    ./setup.sh
fi

source "$CREDFILE"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Credentials file is invalid."
    ./setup.sh
fi

do_deauth() {
    echo "Deauthenticating old session..."
    curl -s -X POST "$PORTAL/submit/del_old_user_session.php" \
      --data-urlencode "pcomp=hotspot" \
      --data-urlencode "usrname=$USERNAME" \
      --data-urlencode "newpasswd=$PASSWORD" \
      -o /tmp/deauth_response.html
    echo "Deauth sent at $(date)"
}

do_login() {
    echo "Logging in as $USERNAME ..."
    curl -s -X POST "$PORTAL/submit/user_login.php" \
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

if curl -s -o /dev/null -w "%{http_code}" http://neverssl.com/ | grep -q "200"; then
    echo "Connected to the internet."
else
    echo "Still not connected — check the portal manually."
fi
