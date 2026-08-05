# BIT WiFi Auto Login

Automatically logs you into BIT's WiFi portal — and kicks out any other device using your account first (since only one device can be connected at a time).

## Linux

```bash
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
chmod +x setup.sh nlogin.sh
./setup.sh
```

This asks for your WiFi username and password once, saves them securely, and sets up `nlogin` as a command you can run from anywhere.

Open a new terminal after this (or run `source ~/.bashrc`), then:

```bash
nlogin
```

## Windows

Requires [Git for Windows](https://git-scm.com/download/win) (includes Git Bash).

**Setup (one time, in Git Bash):**
```bash
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
sed -i 's/\r$//' nlogin.sh setup.sh
chmod +x setup.sh nlogin.sh
./setup.sh
```

**To connect:** just double-click **`nlogin.bat`** in the folder. A window will run the login and show the result.

Tip: right-click `nlogin.bat` → **Send to** → **Desktop (create shortcut)** for one-click access anytime.

## Note

Your password stays only on your machine, in a file only you can read. It's never uploaded anywhere except BIT's own WiFi login page.
