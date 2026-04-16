# ArtKrit Installation Script for Windows (PowerShell)
# Tested with Krita 5.2.9
#
# Downloads official Krita portable ZIP (no system install needed).
# Downloads Python embeddable package (no installer needed, WDAC-safe).
# All dependencies stored inside ArtKrit folder.
#
# Usage:
#   First, enable script execution (one-time):
#     Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#   Then run:
#     .\install.ps1

$ErrorActionPreference = "Stop"

$KRITA_VERSION = "5.2.9"
$KRITA_ZIP_SHA256 = "d009ddf11ce73016c1865383fc59f77e5303c4eef7e2b13a0451aa7ec2cfa5fc"
$PYTHON_VERSION = "3.10.11"
$PYTHON_EMBED_URL = "https://www.python.org/ftp/python/$PYTHON_VERSION/python-$PYTHON_VERSION-embed-amd64.zip"
$GET_PIP_URL = "https://bootstrap.pypa.io/get-pip.py"

Write-Host "==================================="
Write-Host "ArtKrit Installation"
Write-Host "==================================="
Write-Host ""

# Set variables
$SCRIPT_DIR = $PSScriptRoot
$VENV_DIR = Join-Path $SCRIPT_DIR ".venv"
$KRITA_DIR = Join-Path $SCRIPT_DIR "krita"
$PYKRITA_DIR = Join-Path $env:APPDATA "krita\pykrita"
$PYTHON_DIR = Join-Path $SCRIPT_DIR ".python"
$PYTHON_EXE = Join-Path $PYTHON_DIR "python.exe"
$SITE_PACKAGES = Join-Path $VENV_DIR "Lib\site-packages"

Write-Host "ArtKrit folder: $SCRIPT_DIR"
Write-Host "Krita portable: $KRITA_DIR"
Write-Host "Plugin dir:     $PYKRITA_DIR"
Write-Host "Virtual env:    $VENV_DIR"
Write-Host ""

# ---------------------------------------------------------------------------
# Step 1: Setup portable Python
# ---------------------------------------------------------------------------
Write-Host "--- Python Setup ---"
if (Test-Path $PYTHON_EXE) {
    Write-Host "Portable Python already exists, skipping download..."
} else {
    $embedZip = Join-Path $SCRIPT_DIR "python-$PYTHON_VERSION-embed-amd64.zip"
    if (Test-Path $embedZip) {
        Write-Host "Found python-$PYTHON_VERSION-embed-amd64.zip, using local file..."
    } else {
        Write-Host "Downloading Python $PYTHON_VERSION embeddable package..."
        try {
            Invoke-WebRequest -Uri $PYTHON_EMBED_URL -OutFile $embedZip -UseBasicParsing
        } catch {
            Write-Host "ERROR: Failed to download Python embeddable package." -ForegroundColor Red
            Write-Host "  URL: $PYTHON_EMBED_URL"
            Write-Host ""
            Write-Host "Please download it manually and place it as 'python-$PYTHON_VERSION-embed-amd64.zip' in:"
            Write-Host "  $SCRIPT_DIR"
            Read-Host "Press Enter to exit"
            exit 1
        }
    }

    Write-Host "Extracting..."
    if (Test-Path $PYTHON_DIR) { Remove-Item $PYTHON_DIR -Recurse -Force }
    Expand-Archive -Path $embedZip -DestinationPath $PYTHON_DIR -Force
    Remove-Item $embedZip -Force -ErrorAction SilentlyContinue

    # Enable import site so pip and packages work.
    # The ._pth file ships with "import site" commented out.
    $pthFile = Get-ChildItem -Path $PYTHON_DIR -Filter "python*._pth" | Select-Object -First 1
    if ($pthFile) {
        $content = Get-Content $pthFile.FullName -Raw
        $content = $content -replace '#\s*import site', 'import site'
        Set-Content $pthFile.FullName $content -NoNewline
    }

    Write-Host "Portable Python installed!"
}

# Verify python.exe works
try {
    $pyVer = & $PYTHON_EXE --version 2>&1
    Write-Host "Python: $pyVer"
} catch {
    Write-Host "ERROR: python.exe cannot run. It may be blocked by Device Guard." -ForegroundColor Red
    Write-Host "Please install Python 3.10 manually and follow the README instructions."
    Read-Host "Press Enter to exit"
    exit 1
}

# Bootstrap pip if needed
$ErrorActionPreference = "Continue"
& $PYTHON_EXE -m pip --version 2>&1 | Out-Null
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Bootstrapping pip..."
    $getPipFile = Join-Path $PYTHON_DIR "get-pip.py"
    Invoke-WebRequest -Uri $GET_PIP_URL -OutFile $getPipFile -UseBasicParsing
    & $PYTHON_EXE $getPipFile --no-warn-script-location
    if ($LASTEXITCODE -ne 0) { throw "Failed to bootstrap pip" }
    Remove-Item $getPipFile -Force -ErrorAction SilentlyContinue
    Write-Host "pip installed!"
} else {
    Write-Host "pip: already available"
}
Write-Host ""

# ---------------------------------------------------------------------------
# Step 2: Download and setup Krita portable
# ---------------------------------------------------------------------------
Write-Host "--- Krita Setup ---"
$KRITA_ZIP_NAME = "krita-x64-$KRITA_VERSION.zip"
$KRITA_URL = "https://download.kde.org/stable/krita/$KRITA_VERSION/$KRITA_ZIP_NAME"
$KRITA_ZIP = Join-Path $SCRIPT_DIR $KRITA_ZIP_NAME
$KRITA_EXE = Join-Path $KRITA_DIR "bin\krita.exe"

if (Test-Path $KRITA_EXE) {
    Write-Host "Krita portable already exists, skipping download..."
} else {
    if (Test-Path $KRITA_ZIP) {
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

    $KRITA_TEMP = Join-Path $SCRIPT_DIR "__krita_extract__"
    if (Test-Path $KRITA_TEMP) { Remove-Item $KRITA_TEMP -Recurse -Force }
    Expand-Archive -Path $KRITA_ZIP -DestinationPath $KRITA_TEMP -Force

    if (Test-Path $KRITA_DIR) { Remove-Item $KRITA_DIR -Recurse -Force }

    $tempKritaExe = Join-Path $KRITA_TEMP "bin\krita.exe"
    if (Test-Path $tempKritaExe) {
        Rename-Item $KRITA_TEMP "krita"
    } else {
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
Write-Host ""

# ---------------------------------------------------------------------------
# Step 3: Setup plugin directory
# ---------------------------------------------------------------------------
Write-Host "--- Plugin Setup ---"
if (-not (Test-Path $PYKRITA_DIR)) { New-Item -ItemType Directory -Path $PYKRITA_DIR -Force | Out-Null }

$ARTKRIT_DEST = Join-Path $PYKRITA_DIR "ArtKrit"
if (Test-Path $ARTKRIT_DEST) {
    cmd /c "rmdir `"$ARTKRIT_DEST`"" 2>$null
    if (Test-Path $ARTKRIT_DEST) { Remove-Item $ARTKRIT_DEST -Recurse -Force }
}

cmd /c "mklink /J `"$ARTKRIT_DEST`" `"$SCRIPT_DIR`"" >$null 2>&1
if (-not (Test-Path $ARTKRIT_DEST)) {
    Write-Host "Junction failed. Copying files instead..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ARTKRIT_DEST -Force | Out-Null
    Copy-Item "$SCRIPT_DIR\*.py" $ARTKRIT_DEST -Force
    Copy-Item (Join-Path $SCRIPT_DIR "script") $ARTKRIT_DEST -Recurse -Force
}
Write-Host "ArtKrit linked to: $ARTKRIT_DEST"

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
Write-Host "Plugin directory configured."
Write-Host ""

# ---------------------------------------------------------------------------
# Step 4: Install Python dependencies
# ---------------------------------------------------------------------------
Write-Host "--- Dependencies ---"
$skipDeps = $false
if (Test-Path $SITE_PACKAGES) {
    $existingPkgs = Get-ChildItem $SITE_PACKAGES -Directory -ErrorAction SilentlyContinue
    if ($existingPkgs.Count -gt 0) {
        Write-Host "Dependencies already installed ($($existingPkgs.Count) packages found)."
        $reinstall = Read-Host "Reinstall dependencies? (y/N)"
        if ($reinstall -ne "y" -and $reinstall -ne "Y") {
            Write-Host "Skipping dependency installation."
            $skipDeps = $true
        }
    }
}

if (-not $skipDeps) {
    if (-not (Test-Path $SITE_PACKAGES)) {
        New-Item -ItemType Directory -Path $SITE_PACKAGES -Force | Out-Null
    }

    Write-Host "Installing dependencies (this may take a few minutes)..."
    Write-Host ""

    Write-Host "Installing PyTorch..."
    & $PYTHON_EXE -m pip install --target $SITE_PACKAGES torch torchvision torchaudio --no-warn-script-location
    if ($LASTEXITCODE -ne 0) { throw "Failed to install PyTorch" }

    Write-Host ""
    Write-Host "Installing other dependencies..."
    $reqFile = Join-Path $SCRIPT_DIR "requirements.txt"
    & $PYTHON_EXE -m pip install --target $SITE_PACKAGES -r $reqFile --no-warn-script-location
    if ($LASTEXITCODE -ne 0) { throw "Failed to install dependencies" }
}
Write-Host ""

# ---------------------------------------------------------------------------
# Step 5: Create launcher scripts
# ---------------------------------------------------------------------------
Write-Host "--- Launcher Scripts ---"

@'
# ArtKrit Krita Launcher - waits for Krita and streams console logs
$ScriptDir = $PSScriptRoot
$KritaExe = Join-Path $ScriptDir "krita\bin\krita.exe"

$env:QT_LOGGING_TO_CONSOLE = "1"

Write-Host "Starting Krita with console logging..."
Write-Host "This window stays open until Krita exits."
Write-Host ""

& $KritaExe @args | Write-Host
Write-Host ""
Write-Host "Krita has exited."
Read-Host "Press Enter to close"
'@ | Set-Content (Join-Path $SCRIPT_DIR "run-krita.ps1") -Encoding UTF8

@'
# ArtKrit Composition Server (using portable Python)
$ScriptDir = $PSScriptRoot
$PythonExe = Join-Path $ScriptDir ".python\python.exe"
$SitePackages = Join-Path $ScriptDir ".venv\Lib\site-packages"

$env:PYTHONPATH = $SitePackages

Write-Host "Starting ArtKrit composition server..."
Write-Host "Press Ctrl+C to stop."
Write-Host ""

& $PythonExe (Join-Path $ScriptDir "script\composition\server.py") @args
if ($LASTEXITCODE -ne 0) {
    Write-Host "Server exited with error code: $LASTEXITCODE" -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@ | Set-Content (Join-Path $SCRIPT_DIR "run-server.ps1") -Encoding UTF8

Write-Host "Launcher scripts created."
Write-Host ""
Write-Host "==================================="
Write-Host "Installation Complete!"
Write-Host "==================================="
Write-Host ""
Write-Host "To run ArtKrit:"
Write-Host "  1. .\run-krita.ps1    (launches Krita with console logs)"
Write-Host "  2. .\run-server.ps1   (starts the composition server)"
Write-Host ""
Write-Host "First time setup in Krita:"
Write-Host "  1. Go to Settings > Configure Krita > Python Plugin Manager"
Write-Host "  2. Enable 'ArtKrit' checkbox"
Write-Host "  3. Restart Krita (close and run .\run-krita.ps1 again)"
Write-Host "  4. Find the docker under Settings > Dockers > ArtKrit"
Write-Host ""
Write-Host "Plugin data stored in: $PYKRITA_DIR"
Write-Host ""
Write-Host "To uninstall: delete the krita folder and remove $ARTKRIT_DEST"
Write-Host ""
Read-Host "Press Enter to exit"
