@echo off
title BIT WiFi Auto Login
setlocal enabledelayedexpansion

set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"

if not exist "!GIT_BASH!" (
    if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
        set "GIT_BASH=C:\Program Files (x86)\Git\bin\bash.exe"
    ) else (
        for /f "tokens=*" %%i in ('where bash 2^>nul') do (
            set "GIT_BASH=%%i"
        )
    )
)

if not exist "!GIT_BASH!" (
    echo [ERROR] Git Bash was not found on your computer.
    echo Please download and install Git for Windows from https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:\=/%"

"!GIT_BASH!" -c "cd '%SCRIPT_DIR%' && ./nlogin.sh"

echo.
echo Press any key to exit...
pause >nul
