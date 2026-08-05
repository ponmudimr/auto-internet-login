<div align="center">

# 🔐 BIT WiFi Auto Login

**One command to reclaim your WiFi session — no more manual logout/login when switching devices.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-blue)](#)
[![Made for BIT Sathy](https://img.shields.io/badge/made%20for-BIT%20Sathy-orange)](#)

</div>

---

## The Problem

Bannari Amman Institute of Technology's WiFi captive portal only allows **one active device per account**. Switching from laptop to phone (or vice versa) means manually opening the portal, logging out, and logging back in — every single time.

## The Fix

A lightweight script that automates the entire flow into **one command** (Linux) or **one double-click** (Windows). It deauthenticates your other active session, logs in the current device, and confirms you're actually online.

---

## 🚀 Setup Guide

### 🐧 Linux

```bash
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
chmod +x setup.sh nlogin.sh
./setup.sh
```

Enter your WiFi credentials once when prompted. Open a new terminal (or run `source ~/.bashrc`), then run `nlogin` from anywhere.

---

### 🪟 Windows — Step by Step

**Step 1: Install Git for Windows**

You need Git Bash, which comes bundled with Git for Windows.

- **Official method (recommended):** Go to [git-scm.com/download/win](https://git-scm.com/download/win) and click the auto-download link at the top.
- **Alternate direct download:** [Git-2.55.0.3-64-bit.exe](https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.3/Git-2.55.0.3-64-bit.exe)

Once downloaded, double-click the `.exe` file to start the installer.

**Step 2: Run through the installer**

Click **Next** on every screen, keeping all default options selected. On the "Adjusting your PATH environment" screen, make sure **"Git from the command line and also from 3rd-party software"** is selected (it's the default). Click **Install**, then **Finish**.

**Step 3: Open Git Bash**

There are two easy ways:

- **Right-click method:** Right-click anywhere on your **Desktop** → click **"Git Bash Here"** from the menu.
- **Start Menu method:** Click the **Windows Start button** (bottom-left) → type `Git Bash` → press **Enter**.

A black terminal window will open — this is Git Bash. This is where you'll type all the commands below.

**Step 4: Clone the repo onto your Desktop**

Copy-paste this into the Git Bash window and press Enter:

```bash
cd ~/Desktop
git clone https://github.com/ponmudimr/auto-internet-login.git
cd auto-internet-login
```

This creates an `auto-internet-login` folder right on your Desktop, so it's easy to find.

**Step 5: Prepare the scripts**

```bash
sed -i 's/\r$//' nlogin.sh setup.sh
chmod +x setup.sh nlogin.sh
```

**Step 6: Run setup**

```bash
./setup.sh
```

Enter your BIT WiFi username and password when asked (your password won't show as you type — that's normal, just type it and press Enter).

**Step 7: You're done — connect anytime**

- Open **File Explorer → Desktop → auto-internet-login**
- Double-click **`nlogin.bat`**
- A window will open, run the login, and show you the result

> 💡 **Tip:** Right-click `nlogin.bat` → *Send to* → *Desktop (create shortcut)*. Now you have a shortcut icon directly on your Desktop — no need to open the folder each time.

---

## ⚙️ How It Works

The script replicates the exact HTTP requests your browser sends to the captive portal — captured and reverse-engineered via Chrome DevTools' Network tab:

1. **Deauth** → `POST /submit/del_old_user_session.php` — kills the session on your other device
2. **Login** → `POST /submit/user_login.php` — logs in the current device
3. **Verify** → checks real internet connectivity before reporting success

No browser automation, no third-party dependencies — just `curl`.

---

## 🔒 Security

- Credentials are stored **only on your machine**, with file permissions locked to your user
- Nothing is ever committed to this repo or transmitted anywhere except BIT's own WiFi portal
- Review the code yourself — it's a single readable bash script

---

## 🤝 Contributing

This is a small tool built for the BIT community, and it gets better with more hands on it. Ideas for contributions:

- Native PowerShell version (no Git Bash dependency)
- macOS support
- Auto-run on WiFi connect (NetworkManager / systemd hook)

Issues and PRs are welcome — feel free to fork and improve.

---

## ⚠️ Disclaimer

This tool only automates the same login form submission your browser already performs. Use it with your own credentials, in accordance with your institution's IT policies.

---

<div align="center">

If this saved you a few seconds today, consider ⭐ starring the repo.

</div>
