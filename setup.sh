#!/usr/bin/env bash
# One-time setup: saves your BIT WiFi credentials locally and sets up the nlogin command

CRED_DIR="$HOME/.config/bit-wifi"
CREDFILE="$CRED_DIR/credentials"
PROFILES_DIR="$CRED_DIR/profiles"
mkdir -p "$CRED_DIR" "$PROFILES_DIR"
chmod 700 "$CRED_DIR" "$PROFILES_DIR" 2>/dev/null || true

# Preserve any pre-existing credentials file in profiles/ before overwriting
if [ -f "$CREDFILE" ]; then
    OLD_USER=""
    OLD_PASS=""
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in
            USERNAME=*) OLD_USER="${line#USERNAME=}" ;;
            PASSWORD=*) OLD_PASS="${line#PASSWORD=}" ;;
        esac
    done < "$CREDFILE"
    if [ "${#OLD_USER}" -ge 2 ] && [ "${OLD_USER:0:1}" = '"' ] && [ "${OLD_USER: -1}" = '"' ]; then
        OLD_USER="${OLD_USER:1:${#OLD_USER}-2}"
        if [ "${#OLD_PASS}" -ge 2 ] && [ "${OLD_PASS:0:1}" = '"' ] && [ "${OLD_PASS: -1}" = '"' ]; then
            OLD_PASS="${OLD_PASS:1:${#OLD_PASS}-2}"
        fi
    fi
    if [ -n "$OLD_USER" ] && [ -n "$OLD_PASS" ]; then
        OLD_SAFE=$(printf '%s' "$OLD_USER" | tr -c 'a-zA-Z0-9._@-' '_')
        if [ ! -f "$PROFILES_DIR/$OLD_SAFE" ]; then
            (
                umask 077
                printf 'USERNAME=%s\nPASSWORD=%s\n' "$OLD_USER" "$OLD_PASS" > "$PROFILES_DIR/$OLD_SAFE"
            ) 2>/dev/null || true
        fi
    fi
fi

echo "=== BIT WiFi Auto Login Setup ==="
echo ""
read -r -p "Enter your BIT WiFi username (e.g. yourname.ec25@bitsathy.ac.in): " USERNAME
read -r -s -p "Enter your BIT WiFi password: " PASSWORD
echo ""
echo ""

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "❌ Error: Username and password cannot be empty." >&2
    exit 1
fi

SAFE_PROFILE=$(printf '%s' "$USERNAME" | tr -c 'a-zA-Z0-9._@-' '_')
(
    umask 077
    printf 'USERNAME=%s\nPASSWORD=%s\n' "$USERNAME" "$PASSWORD" > "$CREDFILE"
    printf 'USERNAME=%s\nPASSWORD=%s\n' "$USERNAME" "$PASSWORD" > "$PROFILES_DIR/$SAFE_PROFILE"
)
chmod 600 "$CREDFILE" "$PROFILES_DIR/$SAFE_PROFILE" 2>/dev/null || true
echo "✅ Credentials saved securely at ~/.config/bit-wifi/credentials"

# Make local repository scripts executable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR/nlogin.sh" "$SCRIPT_DIR/setup.sh" 2>/dev/null || true

# Determine installation directory based on environment (Termux vs standard Linux/Git Bash)
if [ -n "${PREFIX:-}" ] && [ -d "$PREFIX/bin" ] && [ -w "$PREFIX/bin" ]; then
    INSTALL_DIR="$PREFIX/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
fi

mkdir -p "$INSTALL_DIR" 2>/dev/null || true

if [ -d "$INSTALL_DIR" ]; then
    NLOGIN_SRC=""
    if [ -f "$SCRIPT_DIR/nlogin.sh" ]; then
        NLOGIN_SRC="$SCRIPT_DIR/nlogin.sh"
    elif [ -f "$SCRIPT_DIR/nlogin" ]; then
        NLOGIN_SRC="$SCRIPT_DIR/nlogin"
    fi

    if [ -n "$NLOGIN_SRC" ] && [ "$NLOGIN_SRC" != "$INSTALL_DIR/nlogin" ]; then
        cp "$NLOGIN_SRC" "$INSTALL_DIR/nlogin" 2>/dev/null || true
    fi
    if [ -f "$SCRIPT_DIR/setup.sh" ] && [ "$SCRIPT_DIR/setup.sh" != "$INSTALL_DIR/setup.sh" ]; then
        cp "$SCRIPT_DIR/setup.sh" "$INSTALL_DIR/setup.sh" 2>/dev/null || true
    fi
    chmod +x "$INSTALL_DIR/nlogin" "$INSTALL_DIR/setup.sh" 2>/dev/null || true
    echo "✅ Global command installed at $INSTALL_DIR/nlogin"
else
    echo "⚠️ Warning: Could not create or write to installation directory $INSTALL_DIR"
fi

# Ensure INSTALL_DIR is in PATH
IS_IN_PATH=0
case ":${PATH:-}:" in
    *":$INSTALL_DIR:"*)
        IS_IN_PATH=1
        ;;
esac

if [ $IS_IN_PATH -eq 0 ]; then
    PROFILES=()
    [ -f "$HOME/.bashrc" ] && PROFILES+=("$HOME/.bashrc")
    [ -f "$HOME/.zshrc" ] && PROFILES+=("$HOME/.zshrc")
    [ -f "$HOME/.profile" ] && PROFILES+=("$HOME/.profile")

    if [ ${#PROFILES[@]} -eq 0 ]; then
        PROFILES=("$HOME/.bashrc")
    fi

    EXPORT_CMD="export PATH=\"$INSTALL_DIR:\$PATH\""
    ADDED_PROFILE=""
    for PROF in "${PROFILES[@]}"; do
        if [ -f "$PROF" ] && grep -Eq "^[[:space:]]*export[[:space:]]+PATH=.*$INSTALL_DIR" "$PROF" 2>/dev/null; then
            [ -z "$ADDED_PROFILE" ] && ADDED_PROFILE="$PROF"
        else
            if printf '\n%s\n' "$EXPORT_CMD" >> "$PROF" 2>/dev/null; then
                [ -z "$ADDED_PROFILE" ] && ADDED_PROFILE="$PROF"
                echo "✅ Added $INSTALL_DIR to PATH in $PROF"
            fi
        fi
    done

    # Prefer suggesting the profile matching the user's current $SHELL
    case "${SHELL:-}" in
        */zsh)  [ -f "$HOME/.zshrc" ] && ADDED_PROFILE="$HOME/.zshrc" ;;
        */bash) [ -f "$HOME/.bashrc" ] && ADDED_PROFILE="$HOME/.bashrc" ;;
    esac

    if [ -n "$ADDED_PROFILE" ]; then
        echo ""
        echo "💡 IMPORTANT: To run 'nlogin' from anywhere right now, run:"
        echo "   source $ADDED_PROFILE"
        echo "   (or close and re-open your terminal)"
    else
        echo ""
        echo "⚠️ Could not automatically add $INSTALL_DIR to your PATH."
        echo "   Please manually run or add this command to your shell profile (~/.bashrc or ~/.zshrc):"
        echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
else
    echo "✅ $INSTALL_DIR is already in your PATH."
fi

# Detect Termux environment for phone home screen shortcut (Termux:Widget)
if [ -n "${PREFIX:-}" ] || [ -d "/data/data/com.termux" ]; then
    echo ""
    echo "Android/Termux detected. Creating home screen shortcut..."
    SHORTCUT_DIR="$HOME/.shortcuts"
    mkdir -p "$SHORTCUT_DIR" 2>/dev/null
    cat << EOF > "$SHORTCUT_DIR/nlogin"
#!/usr/bin/env bash
"$INSTALL_DIR/nlogin"
EOF
    chmod +x "$SHORTCUT_DIR/nlogin" 2>/dev/null
    echo "✅ Termux shortcut created at ~/.shortcuts/nlogin"
fi

# Detect Windows environment (Git Bash / MSYS / MINGW) to create Desktop shortcut
IS_WINDOWS=0
case "$(uname -s 2>/dev/null)" in
    CYGWIN*|MINGW*|MSYS*) IS_WINDOWS=1 ;;
esac

if [ $IS_WINDOWS -eq 1 ]; then
    echo ""
    echo "Windows detected. Creating Desktop shortcut..."
    DESKTOP_DIR=""
    if command -v powershell.exe >/dev/null 2>&1; then
        DESKTOP_DIR=$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2>/dev/null | tr -d '\r')
    fi
    if [ -z "$DESKTOP_DIR" ] && [ -d "$HOME/Desktop" ]; then
        DESKTOP_DIR="$HOME/Desktop"
    fi

    if [ -n "$DESKTOP_DIR" ] && [ -f "$SCRIPT_DIR/nlogin.bat" ]; then
        WIN_BAT_PATH="$SCRIPT_DIR/nlogin.bat"
        WIN_SCRIPT_DIR="$SCRIPT_DIR"
        WIN_DESKTOP="$DESKTOP_DIR"
        if command -v cygpath >/dev/null 2>&1; then
            WIN_BAT_PATH=$(cygpath -w "$SCRIPT_DIR/nlogin.bat")
            WIN_SCRIPT_DIR=$(cygpath -w "$SCRIPT_DIR")
            WIN_DESKTOP=$(cygpath -w "$DESKTOP_DIR")
        fi

        SHORTCUT_FILE="$WIN_DESKTOP\\BIT WiFi Auto Login.lnk"

        SHORTCUT_CREATED=0
        if command -v powershell.exe >/dev/null 2>&1; then
            if LNK_PATH="$SHORTCUT_FILE" TARGET_BAT="$WIN_BAT_PATH" WORK_DIR="$WIN_SCRIPT_DIR" \
                powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
                    $ws = New-Object -ComObject WScript.Shell;
                    $s = $ws.CreateShortcut($env:LNK_PATH);
                    $s.TargetPath = $env:TARGET_BAT;
                    $s.WorkingDirectory = $env:WORK_DIR;
                    $s.IconLocation = "shell32.dll,14";
                    $s.Save();
                ' >/dev/null 2>&1; then
                SHORTCUT_CREATED=1
            fi
        fi

        if [ $SHORTCUT_CREATED -eq 0 ] && command -v cscript >/dev/null 2>&1; then
            VBS_TMP=$(mktemp 2>/dev/null || echo "/tmp/create_shortcut_$$.vbs")
            WIN_VBS_TMP="$VBS_TMP"
            if command -v cygpath >/dev/null 2>&1; then
                WIN_VBS_TMP=$(cygpath -w "$VBS_TMP")
            fi
            cat << EOF > "$VBS_TMP"
Set ws = CreateObject("WScript.Shell")
Set s = ws.CreateShortcut("$SHORTCUT_FILE")
s.TargetPath = "$WIN_BAT_PATH"
s.WorkingDirectory = "$WIN_SCRIPT_DIR"
s.IconLocation = "shell32.dll,14"
s.Save
EOF
            if cscript //nologo "$WIN_VBS_TMP" >/dev/null 2>&1; then
                SHORTCUT_CREATED=1
            fi
            rm -f "$VBS_TMP"
        fi

        if [ $SHORTCUT_CREATED -eq 1 ]; then
            echo "✅ Desktop shortcut 'BIT WiFi Auto Login' created on your Desktop!"
        else
            echo "⚠️ Desktop shortcut could not be created automatically."
        fi
    fi
fi

echo ""
echo "✨ Setup completed! You can now run 'nlogin' anytime to connect."
