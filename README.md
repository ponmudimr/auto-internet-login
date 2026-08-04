# BIT WiFi Auto Login

Automatically logs you into BIT's WiFi portal — and kicks out any other device using your account first (since only one device can be connected at a time).

> ⚠️ **Linux only.** This will not work on Windows or macOS.


## Setup (one time)

```bash
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
chmod +x setup.sh nlogin.sh
./setup.sh
```

It'll ask for your WiFi username and password once, save them safely on your own machine, and set up `nlogin` as a command you can use anywhere.

Open a new terminal after this (or run `source ~/.bashrc`).

## Usage

Whenever you need to connect:

```bash
nlogin
```

That's it. It disconnects your other device and logs this one in.

## Note

Your password stays only on your machine, in a file only you can read. It's never uploaded anywhere except BIT's own WiFi login page.
