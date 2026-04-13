#!/bin/bash
# ArtKrit Fully Portable Installation Script for macOS and Linux
# Tested with Krita 5.2.9
#
# This creates a FULLY PORTABLE installation:
# - Krita portable is downloaded and extracted
# - All Krita config/data stored locally (not in ~/.config or ~/Library)
# - Virtual environment is stored inside ArtKrit/.venv
# - To uninstall: just delete the ArtKrit folder

set -e

KRITA_VERSION="5.2.9"
KRITA_APPIMAGE="krita-${KRITA_VERSION}-x86_64.appimage"
KRITA_DMG="krita-${KRITA_VERSION}.dmg"

echo "==================================="
echo "ArtKrit Fully Portable Installation"
echo "==================================="

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    echo "Detected: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    echo "Detected: Linux"
else
    echo "Unsupported OS: $OSTYPE"
    echo "Please use install.bat for Windows"
    exit 1
fi

# Get the directory where this script is located (ArtKrit repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
KRITA_DIR="$SCRIPT_DIR/krita"
KRITA_DATA_DIR="$SCRIPT_DIR/krita-data"
PYKRITA_DIR="$KRITA_DATA_DIR/krita/pykrita"

echo "ArtKrit folder: $SCRIPT_DIR"
echo "Krita portable: $KRITA_DIR"
echo "Krita data: $KRITA_DATA_DIR"
echo "Virtual env: $VENV_DIR"
echo ""

# Check if uv is installed, install if not
if ! command -v uv &> /dev/null; then
    echo "Installing uv package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Download and setup Krita portable
echo ""
if [ -d "$KRITA_DIR" ] || [ -f "$KRITA_DIR" ]; then
    echo "Krita portable already exists, skipping download..."
else
    echo "Downloading Krita ${KRITA_VERSION} portable..."

    if [[ "$OS" == "linux" ]]; then
        # Linux: Download AppImage
        KRITA_URL="https://download.kde.org/stable/krita/${KRITA_VERSION}/${KRITA_APPIMAGE}"
        curl -L -o "$SCRIPT_DIR/$KRITA_APPIMAGE" "$KRITA_URL"
        chmod +x "$SCRIPT_DIR/$KRITA_APPIMAGE"

        # Extract AppImage
        echo "Extracting Krita AppImage..."
        cd "$SCRIPT_DIR"
        ./"$KRITA_APPIMAGE" --appimage-extract
        mv squashfs-root krita
        rm "$KRITA_APPIMAGE"
        cd "$SCRIPT_DIR"

    elif [[ "$OS" == "macos" ]]; then
        # macOS: Download DMG and extract
        KRITA_URL="https://download.kde.org/stable/krita/${KRITA_VERSION}/${KRITA_DMG}"
        curl -L -o "$SCRIPT_DIR/$KRITA_DMG" "$KRITA_URL"

        echo "Extracting Krita from DMG..."
        hdiutil attach "$SCRIPT_DIR/$KRITA_DMG" -mountpoint /Volumes/Krita -quiet
        cp -R "/Volumes/Krita/krita.app" "$KRITA_DIR"
        hdiutil detach /Volumes/Krita -quiet
        rm "$SCRIPT_DIR/$KRITA_DMG"
    fi

    echo "Krita portable installed!"
fi

# Create portable data directories (XDG structure)
# This keeps ALL Krita data inside our folder
echo ""
echo "Setting up portable data directories..."
mkdir -p "$KRITA_DATA_DIR/krita"          # XDG_DATA_HOME/krita
mkdir -p "$KRITA_DATA_DIR/config"         # For kritarc config
mkdir -p "$PYKRITA_DIR"                    # Plugin directory

# Create symlink to ArtKrit in pykrita folder
ARTKRIT_DEST="$PYKRITA_DIR/ArtKrit"
if [ -L "$ARTKRIT_DEST" ]; then
    rm "$ARTKRIT_DEST"
elif [ -d "$ARTKRIT_DEST" ]; then
    rm -rf "$ARTKRIT_DEST"
fi
ln -s "$SCRIPT_DIR" "$ARTKRIT_DEST"

# Create artkrit.desktop file
DESKTOP_FILE="$PYKRITA_DIR/artkrit.desktop"
cat > "$DESKTOP_FILE" << 'EOF'
[Desktop Entry]
Type=Service
ServiceTypes=Krita/PythonPlugin
X-KDE-Library=ArtKrit
X-Python-2-Compatible=false
X-Krita-Manual=Manual.html
Name=ArtKrit
Comment=Docker for ArtKrit
EOF

# Create Python virtual environment INSIDE project folder (portable)
echo ""
if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment already exists."
    read -p "Reinstall dependencies? (y/N): " reinstall
    if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
        echo "Skipping dependency installation."
        echo ""
        goto_done=true
    fi
fi

if [ "$goto_done" != "true" ]; then
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating portable virtual environment with Python 3.10..."
        uv venv "$VENV_DIR" --python 3.10
    fi

    # Install dependencies
    echo ""
    echo "Installing dependencies (this may take a few minutes)..."
    source "$VENV_DIR/bin/activate"

    echo "Installing PyTorch..."
    uv pip install torch torchvision torchaudio

    echo "Installing other dependencies..."
    uv pip install -r "$SCRIPT_DIR/requirements.txt"
fi

# Create launcher script with XDG overrides for full portability
echo ""
echo "Creating launcher script..."
LAUNCHER="$SCRIPT_DIR/run-krita.sh"
if [[ "$OS" == "linux" ]]; then
    cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/bin/bash
# ArtKrit Portable Krita Launcher
# All data stored in krita-data/ folder (fully portable)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Override XDG paths to keep all data local
export XDG_DATA_HOME="$SCRIPT_DIR/krita-data"
export XDG_CONFIG_HOME="$SCRIPT_DIR/krita-data/config"
export XDG_CACHE_HOME="$SCRIPT_DIR/krita-data/cache"

echo "Starting Krita (portable mode)..."
echo "Data folder: $XDG_DATA_HOME"

"$SCRIPT_DIR/krita/AppRun" "$@"
LAUNCHER_EOF
elif [[ "$OS" == "macos" ]]; then
    cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/bin/bash
# ArtKrit Portable Krita Launcher for macOS
# Note: XDG vars may not work for GUI apps on macOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try XDG overrides (may not work for macOS GUI apps)
export XDG_DATA_HOME="$SCRIPT_DIR/krita-data"
export XDG_CONFIG_HOME="$SCRIPT_DIR/krita-data/config"
export XDG_CACHE_HOME="$SCRIPT_DIR/krita-data/cache"

echo "Starting Krita..."
echo "Note: macOS may still use ~/Library for some settings"

"$SCRIPT_DIR/krita/Contents/MacOS/krita" "$@"
LAUNCHER_EOF
fi
chmod +x "$LAUNCHER"

echo ""
echo "==================================="
echo "Installation Complete!"
echo "==================================="
echo ""
echo "To run Krita with ArtKrit:"
echo "  ./run-krita.sh"
echo ""
echo "First time setup in Krita:"
echo "1. Go to Settings > Configure Krita > Python Plugin Manager"
echo "2. Enable 'ArtKrit' checkbox"
echo "3. Restart Krita"
echo "4. Find the docker under Settings > Dockers > ArtKrit"
echo ""
echo "All Krita data stored in: $KRITA_DATA_DIR"
echo ""
echo "To uninstall: just delete this folder"
echo "  rm -rf $SCRIPT_DIR"
