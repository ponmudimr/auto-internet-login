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

# Make nlogin.sh executable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR/nlogin.sh" "$SCRIPT_DIR/setup.sh"

# Install nlogin and setup globally into ~/.local/bin
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/nlogin.sh" "$INSTALL_DIR/nlogin"
cp "$SCRIPT_DIR/setup.sh" "$INSTALL_DIR/setup.sh"
chmod +x "$INSTALL_DIR/nlogin" "$INSTALL_DIR/setup.sh"

# Ensure ~/.local/bin is in PATH if needed
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    SHELL_PROFILE=""
    if [ -f "$HOME/.bashrc" ]; then
        SHELL_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
    fi

    if [ -n "$SHELL_PROFILE" ]; then
        if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_PROFILE"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_PROFILE"
            echo "Added ~/.local/bin to PATH in $SHELL_PROFILE"
        fi
    fi
fi

echo "Credentials saved securely at ~/.config/bit-wifi/credentials"
echo "Success! 'nlogin' installed globally."
echo "You can now run 'nlogin' from anywhere in your terminal."
