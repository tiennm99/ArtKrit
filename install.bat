@echo off
REM ArtKrit Installation Script for Windows
REM Tested with Krita 5.2.9
REM
REM Downloads official Krita portable ZIP (no system install needed).
REM Virtual environment stored inside ArtKrit\.venv
REM To uninstall Krita portable: delete the krita folder
REM To uninstall ArtKrit: remove the junction from pykrita

setlocal enabledelayedexpansion

set "KRITA_VERSION=5.2.9"
set "KRITA_ZIP_SHA256=d009ddf11ce73016c1865383fc59f77e5303c4eef7e2b13a0451aa7ec2cfa5fc"

echo ===================================
echo ArtKrit Installation
echo ===================================
echo.

REM Set variables
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "VENV_DIR=%SCRIPT_DIR%\.venv"
set "KRITA_DIR=%SCRIPT_DIR%\krita"
set "PYKRITA_DIR=%APPDATA%\krita\pykrita"

echo ArtKrit folder: %SCRIPT_DIR%
echo Krita portable: %KRITA_DIR%
echo Plugin dir: %PYKRITA_DIR%
echo Virtual env: %VENV_DIR%
echo.

REM Check if uv is installed
where uv >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo Installing uv package manager...
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    echo.
    echo uv has been installed. Please restart your terminal and run this script again.
    pause
    exit /b 1
)

REM Download and setup Krita portable (official ZIP from KDE)
echo.
set "KRITA_ZIP_NAME=krita-x64-!KRITA_VERSION!.zip"
set "KRITA_URL=https://download.kde.org/stable/krita/!KRITA_VERSION!/!KRITA_ZIP_NAME!"
set "KRITA_ZIP=!SCRIPT_DIR!\!KRITA_ZIP_NAME!"

if exist "!KRITA_DIR!\bin\krita.exe" (
    echo Krita portable already exists, skipping download...
) else (
    REM Check if user already downloaded the ZIP into the folder
    if exist "!KRITA_ZIP!" (
        echo Found !KRITA_ZIP_NAME!, verifying hash...
        for /f %%h in ('powershell -Command "(Get-FileHash -Algorithm SHA256 '!KRITA_ZIP!').Hash"') do set "FILE_HASH=%%h"
        if /i "!FILE_HASH!"=="!KRITA_ZIP_SHA256!" (
            echo Hash verified. Using local file.
        ) else (
            echo ERROR: Hash mismatch! Expected: !KRITA_ZIP_SHA256!
            echo                          Got: !FILE_HASH!
            echo The file may be corrupted. Delete it and re-run, or download again.
            pause
            exit /b 1
        )
    ) else (
        echo Downloading Krita !KRITA_VERSION! portable...
        echo This is the official portable ZIP from krita.org.
        echo.

        powershell -Command "Invoke-WebRequest -Uri '!KRITA_URL!' -OutFile '!KRITA_ZIP!'"

        if not exist "!KRITA_ZIP!" (
            echo ERROR: Failed to download Krita. Please check your internet connection.
            echo URL: !KRITA_URL!
            echo.
            echo You can also download it manually and place it in:
            echo   !SCRIPT_DIR!
            pause
            exit /b 1
        )

        echo Verifying download hash...
        for /f %%h in ('powershell -Command "(Get-FileHash -Algorithm SHA256 '!KRITA_ZIP!').Hash"') do set "FILE_HASH=%%h"
        if /i not "!FILE_HASH!"=="!KRITA_ZIP_SHA256!" (
            echo ERROR: Downloaded file hash mismatch!
            echo Expected: !KRITA_ZIP_SHA256!
            echo      Got: !FILE_HASH!
            del "!KRITA_ZIP!" 2>nul
            pause
            exit /b 1
        )
        echo Hash verified.
    )

    echo Extracting Krita portable...
    echo Please wait, this may take a minute...

    REM Extract to a temp folder, then move to krita/
    set "KRITA_TEMP=!SCRIPT_DIR!\__krita_extract__"
    if exist "!KRITA_TEMP!" rmdir /s /q "!KRITA_TEMP!"
    powershell -Command "Expand-Archive -Path '!KRITA_ZIP!' -DestinationPath '!KRITA_TEMP!' -Force"

    REM Clean up any leftover krita folder from a previous failed install
    if exist "!KRITA_DIR!" rmdir /s /q "!KRITA_DIR!"

    REM Handle both cases: ZIP with subfolder or files at root
    REM Check if bin/krita.exe exists directly in the temp folder
    if exist "!KRITA_TEMP!\bin\krita.exe" (
        REM Files extracted at root level - rename temp folder to krita
        ren "!KRITA_TEMP!" "krita"
    ) else (
        REM Files inside a subfolder - find it and rename
        set "FOUND_SUBFOLDER="
        for /d %%i in ("!KRITA_TEMP!\*") do (
            if exist "%%i\bin\krita.exe" (
                set "FOUND_SUBFOLDER=%%i"
            )
        )
        if defined FOUND_SUBFOLDER (
            REM Move subfolder contents to krita/
            if exist "!KRITA_DIR!" rmdir /s /q "!KRITA_DIR!"
            move "!FOUND_SUBFOLDER!" "!KRITA_DIR!" >nul
            rmdir /s /q "!KRITA_TEMP!" 2>nul
        ) else (
            echo ERROR: Could not find krita.exe in extracted files.
            echo Please extract !KRITA_ZIP_NAME! manually into a folder called "krita".
            rmdir /s /q "!KRITA_TEMP!" 2>nul
            pause
            exit /b 1
        )
    )

    del "!KRITA_ZIP!" 2>nul
    echo Krita portable installed!
)

REM Create pykrita directory
echo.
echo Setting up plugin directory...
if not exist "!PYKRITA_DIR!" mkdir "!PYKRITA_DIR!"

REM Create symlink/junction to ArtKrit in pykrita folder
set "ARTKRIT_DEST=!PYKRITA_DIR!\ArtKrit"
if exist "!ARTKRIT_DEST!" (
    rmdir "!ARTKRIT_DEST!" 2>nul
    rmdir /s /q "!ARTKRIT_DEST!" 2>nul
)

REM Use junction (works without admin/developer mode)
mklink /J "!ARTKRIT_DEST!" "!SCRIPT_DIR!" >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo WARNING: Could not create link. Copying files instead...
    xcopy /E /I /Y "!SCRIPT_DIR!\*.py" "!ARTKRIT_DEST!\"
    xcopy /E /I /Y "!SCRIPT_DIR!\script" "!ARTKRIT_DEST!\script\"
)

REM Create artkrit.desktop file
(
echo [Desktop Entry]
echo Type=Service
echo ServiceTypes=Krita/PythonPlugin
echo X-KDE-Library=ArtKrit
echo X-Python-2-Compatible=false
echo X-Krita-Manual=Manual.html
echo Name=ArtKrit
echo Comment=Docker for ArtKrit
) > "!PYKRITA_DIR!\artkrit.desktop"

REM Create Python virtual environment INSIDE project folder
echo.
if exist "!VENV_DIR!" (
    echo Virtual environment already exists.
    set /p "reinstall=Reinstall dependencies? (y/N): "
    if /i not "!reinstall!"=="y" (
        echo Skipping dependency installation.
        goto :create_launcher
    )
) else (
    echo Creating virtual environment with Python 3.10...
    uv venv "!VENV_DIR!" --python 3.10
)

REM Install dependencies
echo.
echo Installing dependencies (this may take a few minutes)...
call "!VENV_DIR!\Scripts\activate.bat"

echo Installing PyTorch...
uv pip install torch torchvision torchaudio

echo Installing other dependencies...
uv pip install -r "!SCRIPT_DIR!\requirements.txt"

:create_launcher
REM Create Krita launcher script
echo.
echo Creating launcher scripts...
(
echo @echo off
echo REM ArtKrit Krita Launcher - keeps console open for debug logs
echo.
echo set "SCRIPT_DIR=%%~dp0"
echo set "SCRIPT_DIR=%%SCRIPT_DIR:~0,-1%%"
echo.
echo echo Starting Krita with console logging...
echo echo Close this window to stop viewing logs.
echo echo.
echo.
echo REM start /wait keeps the console open until Krita exits
echo start /wait "" "%%SCRIPT_DIR%%\krita\bin\krita.exe" %%*
) > "!SCRIPT_DIR!\run-krita.bat"

REM Create server launcher script
(
echo @echo off
echo REM ArtKrit Composition Server
echo.
echo set "SCRIPT_DIR=%%~dp0"
echo set "SCRIPT_DIR=%%SCRIPT_DIR:~0,-1%%"
echo.
echo echo Starting ArtKrit composition server...
echo echo Press Ctrl+C to stop.
echo echo.
echo.
echo call "%%SCRIPT_DIR%%\.venv\Scripts\activate.bat"
echo python "%%SCRIPT_DIR%%\script\composition\server.py" %%*
) > "!SCRIPT_DIR!\run-server.bat"

echo.
echo ===================================
echo Installation Complete!
echo ===================================
echo.
echo To run ArtKrit:
echo   1. run-krita.bat    (launches Krita with console logs)
echo   2. run-server.bat   (starts the composition server)
echo.
echo First time setup in Krita:
echo 1. Go to Settings ^> Configure Krita ^> Python Plugin Manager
echo 2. Enable 'ArtKrit' checkbox
echo 3. Restart Krita (close and run run-krita.bat again)
echo 4. Find the docker under Settings ^> Dockers ^> ArtKrit
echo.
echo Plugin data stored in: !PYKRITA_DIR!
echo.
echo To uninstall: delete the krita folder and remove !ARTKRIT_DEST!
echo.
pause
