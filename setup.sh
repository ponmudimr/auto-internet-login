#!/bin/bash
# One-time setup: saves your BIT WiFi credentials locally

mkdir -p ~/.config/bit-wifi

read -p "Enter your BIT WiFi username (e.g. yourname.ec25@bitsathy.ac.in): " USERNAME
read -s -p "Enter your BIT WiFi password: " PASSWORD
echo ""

cat > ~/.config/bit-wifi/credentials << CREDEOF
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
CREDEOF

chmod 600 ~/.config/bit-wifi/credentials

echo "Credentials saved securely at ~/.config/bit-wifi/credentials"
