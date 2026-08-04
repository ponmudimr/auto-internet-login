# BIT WiFi Auto Login

A simple script to automatically deauthenticate your old session and log in to Bannari Amman Institute of Technology's WiFi captive portal, since accounts can only be active on one device at a time.

## Setup

```bash
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
chmod +x setup.sh nlogin.sh
./setup.sh
```

This will ask for your BIT WiFi username and password once, and save them securely (permissions restricted to your user only) at `~/.config/bit-wifi/credentials`.

## Usage

Every time you need to connect (or switch devices):

```bash
./nlogin.sh
```

This will:
1. Deauthenticate any existing session on another device
2. Log in this device
3. Confirm internet connectivity

## Optional: install as a global `nlogin` command

Run this once so you can type `nlogin` from any folder:

```bash
mkdir -p ~/.local/bin
cp nlogin.sh ~/.local/bin/nlogin
chmod +x ~/.local/bin/nlogin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Then just run:

```bash
nlogin
```

## Security note

Your credentials are stored locally on your own machine only, in a file only you can read (`chmod 600`). They are never committed to this repo or sent anywhere except the college's own WiFi portal.

## Disclaimer

This script only automates the same login form submission your browser normally does. Use responsibly and only with your own credentials, in accordance with your institution's IT policies.
