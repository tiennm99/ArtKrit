# ArtKrit Installation Script for Windows (PowerShell)
# Tested with Krita 5.2.14
#
# Downloads official Krita portable ZIP (no system install needed).
# Virtual environment stored inside ArtKrit\.venv
#
# Usage:
#   First, enable script execution (one-time):
#     Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#   Then run:
#     .\install.ps1

$ErrorActionPreference = "Stop"

$KRITA_VERSION = "5.2.14"
$KRITA_ZIP_SHA256 = "fe755f67e8b69297717e8a7a5551acf14e998cfa206b6a0aad11368704a735de"

Write-Host "==================================="
Write-Host "ArtKrit Installation"
Write-Host "==================================="
Write-Host ""

# Set variables
$SCRIPT_DIR = $PSScriptRoot
$VENV_DIR = Join-Path $SCRIPT_DIR ".venv"
$KRITA_DIR = Join-Path $SCRIPT_DIR "krita"
$PYKRITA_DIR = Join-Path $env:APPDATA "krita\pykrita"

Write-Host "ArtKrit folder: $SCRIPT_DIR"
Write-Host "Krita portable: $KRITA_DIR"
Write-Host "Plugin dir:     $PYKRITA_DIR"
Write-Host "Virtual env:    $VENV_DIR"
Write-Host ""

# Check if uv is installed
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv package manager..."
    irm https://astral.sh/uv/install.ps1 | iex

    # Refresh PATH with default install locations
    $uvPaths = @(
        (Join-Path $env:USERPROFILE ".local\bin"),
        (Join-Path $env:USERPROFILE ".cargo\bin")
    )
    foreach ($p in $uvPaths) {
        if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) {
            $env:PATH = "$p;$env:PATH"
        }
    }

    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: Failed to install uv. Please install it manually:" -ForegroundColor Red
        Write-Host "  https://docs.astral.sh/uv/getting-started/installation/"
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Host "uv installed successfully."
    Write-Host ""
}

# Download and setup Krita portable (official ZIP from KDE)
$KRITA_ZIP_NAME = "krita-x64-$KRITA_VERSION.zip"
$KRITA_URL = "https://download.kde.org/stable/krita/$KRITA_VERSION/$KRITA_ZIP_NAME"
$KRITA_ZIP = Join-Path $SCRIPT_DIR $KRITA_ZIP_NAME
$KRITA_EXE = Join-Path $KRITA_DIR "bin\krita.exe"

Write-Host ""
if (Test-Path $KRITA_EXE) {
    Write-Host "Krita portable already exists, skipping download..."
} else {
    if (Test-Path $KRITA_ZIP) {
        # User pre-downloaded the ZIP
        Write-Host "Found $KRITA_ZIP_NAME, verifying hash..."
        $hash = (Get-FileHash -Algorithm SHA256 $KRITA_ZIP).Hash
        if ($hash -ne $KRITA_ZIP_SHA256) {
            Write-Host "ERROR: Hash mismatch!" -ForegroundColor Red
            Write-Host "  Expected: $KRITA_ZIP_SHA256"
            Write-Host "       Got: $hash"
            Write-Host "The file may be corrupted. Delete it and re-run, or download again."
            Read-Host "Press Enter to exit"
            exit 1
        }
        Write-Host "Hash verified. Using local file."
    } else {
        # Download
        Write-Host "Downloading Krita $KRITA_VERSION portable..."
        Write-Host "This is the official portable ZIP from krita.org."
        Write-Host ""
        try {
            Invoke-WebRequest -Uri $KRITA_URL -OutFile $KRITA_ZIP
        } catch {
            Write-Host "ERROR: Failed to download Krita. Please check your internet connection." -ForegroundColor Red
            Write-Host "  URL: $KRITA_URL"
            Write-Host ""
            Write-Host "You can also download it manually and place it in:"
            Write-Host "  $SCRIPT_DIR"
            Read-Host "Press Enter to exit"
            exit 1
        }

        Write-Host "Verifying download hash..."
        $hash = (Get-FileHash -Algorithm SHA256 $KRITA_ZIP).Hash
        if ($hash -ne $KRITA_ZIP_SHA256) {
            Write-Host "ERROR: Downloaded file hash mismatch!" -ForegroundColor Red
            Write-Host "  Expected: $KRITA_ZIP_SHA256"
            Write-Host "       Got: $hash"
            Remove-Item $KRITA_ZIP -Force -ErrorAction SilentlyContinue
            Read-Host "Press Enter to exit"
            exit 1
        }
        Write-Host "Hash verified."
    }

    Write-Host "Extracting Krita portable..."
    Write-Host "Please wait, this may take a minute..."

    # Extract to temp folder, then move to krita/
    $KRITA_TEMP = Join-Path $SCRIPT_DIR "__krita_extract__"
    if (Test-Path $KRITA_TEMP) { Remove-Item $KRITA_TEMP -Recurse -Force }
    Expand-Archive -Path $KRITA_ZIP -DestinationPath $KRITA_TEMP -Force

    # Clean up leftover krita folder from a previous failed install
    if (Test-Path $KRITA_DIR) { Remove-Item $KRITA_DIR -Recurse -Force }

    # Handle both cases: ZIP with subfolder or files at root
    $tempKritaExe = Join-Path $KRITA_TEMP "bin\krita.exe"
    if (Test-Path $tempKritaExe) {
        # Files at root level
        Rename-Item $KRITA_TEMP "krita"
    } else {
        # Find subfolder containing bin/krita.exe
        $subfolder = Get-ChildItem -Path $KRITA_TEMP -Directory | Where-Object {
            Test-Path (Join-Path $_.FullName "bin\krita.exe")
        } | Select-Object -First 1

        if ($subfolder) {
            Move-Item $subfolder.FullName $KRITA_DIR
            Remove-Item $KRITA_TEMP -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "ERROR: Could not find krita.exe in extracted files." -ForegroundColor Red
            Write-Host "Please extract $KRITA_ZIP_NAME manually into a folder called 'krita'."
            Remove-Item $KRITA_TEMP -Recurse -Force -ErrorAction SilentlyContinue
            Read-Host "Press Enter to exit"
            exit 1
        }
    }

    Remove-Item $KRITA_ZIP -Force -ErrorAction SilentlyContinue
    Write-Host "Krita portable installed!"
}

# Create pykrita directory
Write-Host ""
Write-Host "Setting up plugin directory..."
if (-not (Test-Path $PYKRITA_DIR)) { New-Item -ItemType Directory -Path $PYKRITA_DIR -Force | Out-Null }

# Create junction to ArtKrit in pykrita folder
$ARTKRIT_DEST = Join-Path $PYKRITA_DIR "ArtKrit"
if (Test-Path $ARTKRIT_DEST) {
    # Remove existing junction or directory
    cmd /c "rmdir `"$ARTKRIT_DEST`"" 2>$null
    if (Test-Path $ARTKRIT_DEST) { Remove-Item $ARTKRIT_DEST -Recurse -Force }
}

# Use junction (works without admin/developer mode)
cmd /c "mklink /J `"$ARTKRIT_DEST`" `"$SCRIPT_DIR`"" >$null 2>&1
if (-not (Test-Path $ARTKRIT_DEST)) {
    Write-Host "WARNING: Could not create junction. Copying files instead..." -ForegroundColor Yellow
    Copy-Item "$SCRIPT_DIR\*.py" $ARTKRIT_DEST -Force
    Copy-Item "$SCRIPT_DIR\script" $ARTKRIT_DEST -Recurse -Force
}

# Create artkrit.desktop file
@"
[Desktop Entry]
Type=Service
ServiceTypes=Krita/PythonPlugin
X-KDE-Library=ArtKrit
X-Python-2-Compatible=false
X-Krita-Manual=Manual.html
Name=ArtKrit
Comment=Docker for ArtKrit
"@ | Set-Content (Join-Path $PYKRITA_DIR "artkrit.desktop") -Encoding UTF8

# Create Python virtual environment
Write-Host ""
$skipDeps = $false
if (Test-Path $VENV_DIR) {
    Write-Host "Virtual environment already exists."
    $reinstall = Read-Host "Reinstall dependencies? (y/N)"
    if ($reinstall -ne "y" -and $reinstall -ne "Y") {
        Write-Host "Skipping dependency installation."
        $skipDeps = $true
    }
} else {
    Write-Host "Creating virtual environment with Python 3.10..."
    uv venv $VENV_DIR --python 3.10
}

if (-not $skipDeps) {
    Write-Host ""
    Write-Host "Installing dependencies (this may take a few minutes)..."
    & "$VENV_DIR\Scripts\activate.bat"

    Write-Host "Installing PyTorch..."
    uv pip install torch torchvision torchaudio

    Write-Host "Installing other dependencies..."
    uv pip install -r (Join-Path $SCRIPT_DIR "requirements.txt")
}

# Create Krita launcher script
Write-Host ""
Write-Host "Creating launcher scripts..."
@'
@echo off
REM ArtKrit Krita Launcher - keeps console open for debug logs

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo Starting Krita with console logging...
echo Close this window to stop viewing logs.
echo.

REM start /wait keeps the console open until Krita exits
start /wait "" "%SCRIPT_DIR%\krita\bin\krita.exe" %*
'@ | Set-Content (Join-Path $SCRIPT_DIR "run-krita.bat") -Encoding ASCII

# Create server launcher script
@'
@echo off
REM ArtKrit Composition Server

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo Starting ArtKrit composition server...
echo Press Ctrl+C to stop.
echo.

call "%SCRIPT_DIR%\.venv\Scripts\activate.bat"
python "%SCRIPT_DIR%\script\composition\server.py" %*
'@ | Set-Content (Join-Path $SCRIPT_DIR "run-server.bat") -Encoding ASCII

Write-Host ""
Write-Host "==================================="
Write-Host "Installation Complete!"
Write-Host "==================================="
Write-Host ""
Write-Host "To run ArtKrit:"
Write-Host "  1. run-krita.bat    (launches Krita with console logs)"
Write-Host "  2. run-server.bat   (starts the composition server)"
Write-Host ""
Write-Host "First time setup in Krita:"
Write-Host "  1. Go to Settings > Configure Krita > Python Plugin Manager"
Write-Host "  2. Enable 'ArtKrit' checkbox"
Write-Host "  3. Restart Krita (close and run run-krita.bat again)"
Write-Host "  4. Find the docker under Settings > Dockers > ArtKrit"
Write-Host ""
Write-Host "Plugin data stored in: $PYKRITA_DIR"
Write-Host ""
Write-Host "To uninstall: delete the krita folder and remove $ARTKRIT_DEST"
Write-Host ""
Read-Host "Press Enter to exit"
