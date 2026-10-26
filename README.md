<div align="center">

# 🔐 BIT WiFi Auto Login

**One command to log into BIT WiFi — no more manual logout/login when switching devices.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20Android-blue)](#)
[![Made for BIT Sathy](https://img.shields.io/badge/made%20for-BIT%20Sathy-orange)](#)

</div>

---

## ❓ The Problem

Bannari Amman Institute of Technology's WiFi captive portal allows only **one active device per student account**. Switching from your phone to your laptop (or vice versa) means manually opening the login page, logging out your old device, and logging in again — every single time.

## 💡 The Fix

This tool automates the entire process into **one single command** (on Linux & Android) or **one double-click / home screen shortcut** (on Windows & Android phones). It disconnects your old session, logs in your current device, and verifies that you are connected to the internet.

---

## 🚀 Setup Guides

Choose your operating system below for quick, step-by-step instructions.

---

### 🐧 Option 1: Linux

#### **Step 1: Open your Terminal**
Press `Ctrl + Alt + T` on your keyboard to open a terminal window.

#### **Step 2: Download and set up**
Copy and paste these commands into your terminal, then press **Enter**:

```bash
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
chmod +x setup.sh nlogin.sh
./setup.sh
```

#### **Step 3: Enter your credentials**
When prompted, type your BIT WiFi username and password. *(Your password will not show characters on screen while typing — this is normal for security).*

#### **Step 4: You're done!**
Open a new terminal window (or run **`source ~/.bashrc`**). Now, whenever you need to connect to WiFi, simply type:

```bash
nlogin
```

---

### 🪟 Option 2: Windows (via Git Bash)

#### **Step 1: Download & Install Git Bash**
You need Git Bash to run the setup.

- **Official Download:** [git-scm.com/download/win](https://git-scm.com/download/win)
- **Direct Download Link:** [Git-2.55.0.3-64-bit.exe](https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.3/Git-2.55.0.3-64-bit.exe)

Run the installer, click **Next** on all screens with default settings, and click **Install**.

#### **Step 2: Open Git Bash**
- Right-click anywhere on your **Desktop** → click **"Git Bash Here"**, OR
- Open the Start Menu, search for **Git Bash**, and press **Enter**.

#### **Step 3: Download and run setup**
Copy and paste these exact commands into the black Git Bash window, then press **Enter**:

```bash
cd ~/Desktop
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
sed -i 's/\r$//' nlogin.sh setup.sh
chmod +x setup.sh nlogin.sh
./setup.sh
```

Enter your BIT WiFi username and password when prompted.

#### **Step 4: Connect anytime with one double-click!**
Setup automatically creates a shortcut named **`BIT WiFi Auto Login`** right on your **Desktop**.

From now on, whenever you want to connect to WiFi, simply **double-click the Desktop shortcut icon**. A small window will pop up, connect you to the WiFi, and display a success message!

---

### 📱 Option 3: Android (via Termux)

#### **Step 1: Install Termux**
Download and install the **Termux** app from **[F-Droid](https://f-droid.org/packages/com.termux/)** *(Recommended: do not use the Google Play Store version as it is outdated)*.

#### **Step 2: Run the setup commands**
Open the Termux app on your phone, copy-paste the following commands, and press **Enter**:

```bash
pkg update && pkg install git -y
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
chmod +x setup.sh nlogin.sh
./setup.sh
```

Enter your BIT WiFi username and password when prompted.

#### **Step 3: Connect anytime via Terminal or Home Screen Shortcut!**

- **In Termux Terminal**: Simply open Termux and type:
  ```bash
  nlogin
  ```

- **📲 1-Tap Home Screen Shortcut (Optional)**:
  Setup automatically creates a Termux shortcut at `~/.shortcuts/nlogin`.
  1. Install **[Termux:Widget](https://f-droid.org/packages/com.termux.widget/)** from F-Droid.
  2. Long-press any empty space on your phone's home screen → select **Widgets**.
  3. Find **Termux:Widget**, drag it to your home screen, and tap **`nlogin`** anytime to log in with 1 tap!

---

## 🧰 Commands & Options

Once set up, you can run `nlogin` from anywhere with the following options:

| Command | Description |
|---------|-------------|
| `nlogin` | Deauthenticate old session, log in current device, and verify internet |
| `nlogin --status` (or `-c`) | Check if BIT WiFi portal and internet connection are reachable |
| `nlogin --logout` (or `-d`) | Disconnect (deauthenticate) your active session without logging back in |
| `nlogin --keepalive [sec]` (or `-k`) | Monitor connection every `sec` seconds (default `60`) and auto-reconnect if dropped |
| `nlogin --setup` (or `-s`) | Configure or update your saved BIT WiFi username and password |
| `nlogin --help` (or `-h`) | Display usage instructions and examples |

---

## 🔄 Changing Your Username or Password

If you change your portal password or switch accounts:
- **Option 1 (Easiest)**: Run **`nlogin --setup`** from any terminal (or **`./setup.sh`** inside the repository folder).
- **Option 2 (Manual Edit)**: Open the saved credentials file in a text editor:
  ```bash
  nano ~/.config/bit-wifi/credentials
  ```

---

## 🔒 Security & Privacy

- **Your credentials stay local**: Username and password are stored **only on your device** at `~/.config/bit-wifi/credentials` with locked file permissions (`chmod 600` via `umask 077`).
- **Hidden from process list**: Passwords are piped to `curl` via standard input (`--data-urlencode newpasswd@-`) so they are never exposed in process tables (`ps aux`).
- **No data is shared**: Credentials are never sent anywhere except directly to BIT Sathy's portal (`172.16.0.200`).
- **Safe credential storage**: Special characters in passwords (like `$`, `#`, `!`, `"`, `\`, `` ` ``) are handled verbatim without shell expansion or code execution risk.

---

## ⚙️ How It Works (For Tech Curious)

The script sends standard web requests directly to the captive portal server (`172.16.0.200:2280`):
1. **Deauthenticate**: Sends a POST request to `/submit/del_old_user_session.php` to clear your active session on other devices and validates that credentials are accepted.
2. **Login**: Sends a POST request to `/submit/user_login.php` to log in your current device.
3. **Verify & Error Handling**: Checks HTTP status codes and portal response text for errors (e.g. wrong credentials, offline network, portal maintenance), then verifies internet access via low-latency HTTP `204` captive-portal endpoints (`connectivitycheck.gstatic.com/generate_204`, `cp.cloudflare.com/generate_204`, with `neverssl.com` fallback).

---

## 🙋 Need Help?

If you run into any issues or something isn't working as expected:
- Please open a **[GitHub Issue](https://github.com/ponmudimr/auto-internet-login/issues)** with details about your operating system and the error message shown.

---

## ⚠️ Disclaimer

This tool simply automates the same web login form that your browser submits. Use it with your own credentials in accordance with your institution's network usage policies.

---

<div align="center">

If this saved you time, consider giving this repository a ⭐ **Star**!

</div>
