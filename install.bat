@echo off
REM ArtKrit Fully Portable Installation Script for Windows
REM Tested with Krita 5.2.9
REM
REM This creates a FULLY PORTABLE installation:
REM - Krita Portable from PortableApps.com (stores all data locally)
REM - Virtual environment is stored inside ArtKrit\.venv
REM - To uninstall: just delete the ArtKrit folder

setlocal enabledelayedexpansion

set "KRITA_VERSION=5.2.9"

echo ===================================
echo ArtKrit Fully Portable Installation
echo ===================================
echo.

REM Set variables
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "VENV_DIR=%SCRIPT_DIR%\.venv"
set "KRITA_DIR=%SCRIPT_DIR%\KritaPortable"
set "KRITA_DATA_DIR=%KRITA_DIR%\Data\krita"
set "PYKRITA_DIR=%KRITA_DATA_DIR%\pykrita"

echo Detected: Windows
echo ArtKrit folder: %SCRIPT_DIR%
echo Krita portable: %KRITA_DIR%
echo Krita data: %KRITA_DATA_DIR%
echo Virtual env: %VENV_DIR%
echo.

REM Check if uv is installed
where uv >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Installing uv package manager...
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    echo.
    echo uv has been installed. Please restart your terminal and run this script again.
    pause
    exit /b 1
)

REM Download and setup Krita Portable (PortableApps.com version for true portability)
echo.
if exist "%KRITA_DIR%" (
    echo Krita portable already exists, skipping download...
) else (
    echo Downloading Krita Portable %KRITA_VERSION%...
    echo This is the PortableApps.com version which stores ALL data locally.
    echo.

    set "KRITA_PORTABLE_URL=https://download.kde.org/stable/krita/%KRITA_VERSION%/KritaPortable-%KRITA_VERSION%.paf.exe"
    set "KRITA_INSTALLER=%SCRIPT_DIR%\KritaPortable-%KRITA_VERSION%.paf.exe"

    powershell -Command "Invoke-WebRequest -Uri '!KRITA_PORTABLE_URL!' -OutFile '!KRITA_INSTALLER!'"

    echo Extracting Krita Portable...
    echo Please wait, this may take a minute...

    REM Run the portable installer in silent mode
    "!KRITA_INSTALLER!" /DESTINATION="%SCRIPT_DIR%" /SILENT

    del "!KRITA_INSTALLER!"
    echo Krita Portable installed!
)

REM Create pykrita directory inside Krita's Data folder (true portable)
echo.
echo Setting up plugin directory...
if not exist "%KRITA_DATA_DIR%" mkdir "%KRITA_DATA_DIR%"
if not exist "%PYKRITA_DIR%" mkdir "%PYKRITA_DIR%"

REM Create symlink/junction to ArtKrit in pykrita folder
set "ARTKRIT_DEST=%PYKRITA_DIR%\ArtKrit"
if exist "%ARTKRIT_DEST%" (
    rmdir "%ARTKRIT_DEST%" 2>nul
    rmdir /s /q "%ARTKRIT_DEST%" 2>nul
)

REM Use junction (works without admin/developer mode)
mklink /J "%ARTKRIT_DEST%" "%SCRIPT_DIR%" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Could not create link. Copying files instead...
    xcopy /E /I /Y "%SCRIPT_DIR%\*.py" "%ARTKRIT_DEST%\"
    xcopy /E /I /Y "%SCRIPT_DIR%\script" "%ARTKRIT_DEST%\script\"
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
) > "%PYKRITA_DIR%\artkrit.desktop"

REM Create Python virtual environment INSIDE project folder (portable)
echo.
if exist "%VENV_DIR%" (
    echo Virtual environment already exists.
    set /p "reinstall=Reinstall dependencies? (y/N): "
    if /i not "!reinstall!"=="y" (
        echo Skipping dependency installation.
        goto :create_launcher
    )
) else (
    echo Creating portable virtual environment with Python 3.10...
    uv venv "%VENV_DIR%" --python 3.10
)

REM Install dependencies
echo.
echo Installing dependencies (this may take a few minutes)...
call "%VENV_DIR%\Scripts\activate.bat"

echo Installing PyTorch...
uv pip install torch torchvision torchaudio

echo Installing other dependencies...
uv pip install -r "%SCRIPT_DIR%\requirements.txt"

:create_launcher
REM Create launcher script
echo.
echo Creating launcher script...
(
echo @echo off
echo REM ArtKrit Portable Krita Launcher
echo REM All data stored in KritaPortable\Data\ folder
echo.
echo set "SCRIPT_DIR=%%~dp0"
echo set "SCRIPT_DIR=%%SCRIPT_DIR:~0,-1%%"
echo.
echo REM For our platform_utils.py
echo set "KRITA_RESOURCE_PATH=%%SCRIPT_DIR%%\KritaPortable\Data\krita\pykrita"
echo.
echo echo Starting Krita Portable...
echo echo Data folder: %%SCRIPT_DIR%%\KritaPortable\Data
echo.
echo "%%SCRIPT_DIR%%\KritaPortable\KritaPortable.exe" %%*
) > "%SCRIPT_DIR%\run-krita.bat"

echo.
echo ===================================
echo Installation Complete!
echo ===================================
echo.
echo To run Krita with ArtKrit:
echo   run-krita.bat
echo.
echo First time setup in Krita:
echo 1. Go to Settings ^> Configure Krita ^> Python Plugin Manager
echo 2. Enable 'ArtKrit' checkbox
echo 3. Restart Krita (close and run run-krita.bat again)
echo 4. Find the docker under Settings ^> Dockers ^> ArtKrit
echo.
echo All Krita data stored in: %KRITA_DATA_DIR%
echo.
echo To uninstall: just delete this folder
echo   %SCRIPT_DIR%
echo.
pause
