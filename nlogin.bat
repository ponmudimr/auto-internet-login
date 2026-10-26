@echo off
title BIT WiFi Auto Login

set "GIT_BASH="

if exist "%ProgramFiles%\Git\bin\bash.exe" (
    set "GIT_BASH=%ProgramFiles%\Git\bin\bash.exe"
) else if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
    set "GIT_BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
) else if exist "%LocalAppData%\Programs\Git\bin\bash.exe" (
    set "GIT_BASH=%LocalAppData%\Programs\Git\bin\bash.exe"
) else (
    for /f "delims=" %%i in ('where bash.exe 2^>nul') do (
        echo "%%i" | findstr /i /c:"\System32\bash.exe" >nul
        if errorlevel 1 (
            if not defined GIT_BASH set "GIT_BASH=%%i"
        )
    )
)

if not defined GIT_BASH (
    echo [ERROR] Git Bash was not found on your computer.
    echo Please download and install Git for Windows from https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

"%GIT_BASH%" "%~dp0nlogin.sh" %*

echo.
echo Press any key to exit...
pause >nul
