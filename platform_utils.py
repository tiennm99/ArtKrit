"""Cross-platform utility functions for ArtKrit"""
import os
import sys


def get_artkrit_dir():
    """Returns the ArtKrit project directory (where this file is located)."""
    return os.path.dirname(os.path.abspath(__file__))


def get_krita_pykrita_dir():
    """
    Returns the Krita pykrita plugins directory.

    Searches in order:
    1. Portable data folder (Linux/macOS: krita-data/krita/pykrita via XDG override)
    2. Legacy local pykrita folder
    3. System default location per platform
    """
    artkrit_dir = get_artkrit_dir()

    # Priority 1: Portable installation path (Linux/macOS with XDG override)
    if sys.platform != "win32":
        portable_pykrita = os.path.join(artkrit_dir, "krita-data", "krita", "pykrita")
        if os.path.exists(portable_pykrita):
            return portable_pykrita

    # Priority 2: Legacy local pykrita folder
    local_pykrita = os.path.join(artkrit_dir, "pykrita")
    if os.path.exists(local_pykrita):
        return local_pykrita

    # Priority 3: System default
    if sys.platform == "win32":
        return os.path.join(os.environ.get("APPDATA", ""), "krita", "pykrita")
    elif sys.platform == "darwin":
        return os.path.expanduser("~/Library/Application Support/krita/pykrita")
    else:  # Linux and other Unix
        return os.path.expanduser("~/.local/share/krita/pykrita")


def get_artkrit_temp_dir():
    """
    Returns the ArtKrit temp directory path (inside project folder for portability).
    Creates the directory if it doesn't exist.
    """
    temp_dir = os.path.join(get_artkrit_dir(), "temp")
    os.makedirs(temp_dir, exist_ok=True)
    return temp_dir


def _get_site_packages_path(venv_dir):
    """Returns site-packages path for a venv directory based on platform."""
    if sys.platform == "win32":
        return os.path.join(venv_dir, "Lib", "site-packages")
    else:
        python_version = f"python{sys.version_info.major}.{sys.version_info.minor}"
        return os.path.join(venv_dir, "lib", python_version, "site-packages")


def get_venv_site_packages():
    """
    Returns the site-packages path for the virtual environment.

    Searches in order:
    1. .venv inside ArtKrit folder (portable installation)
    2. ~/ddraw (legacy installation)

    Returns:
        Path to site-packages directory, or None if not found
    """
    # Priority 1: Portable venv inside project folder
    artkrit_venv = os.path.join(get_artkrit_dir(), ".venv")
    if os.path.exists(artkrit_venv):
        return _get_site_packages_path(artkrit_venv)

    # Priority 2: Legacy ~/ddraw location
    home = os.path.expanduser("~")
    legacy_venv = os.path.join(home, "ddraw")
    if os.path.exists(legacy_venv):
        return _get_site_packages_path(legacy_venv)

    # Return portable path even if doesn't exist (for error messages)
    return _get_site_packages_path(artkrit_venv)


def setup_venv_path():
    """
    Adds the virtual environment site-packages to sys.path if it exists.

    Returns:
        True if path was added, False otherwise
    """
    site_packages = get_venv_site_packages()
    if site_packages and os.path.exists(site_packages) and site_packages not in sys.path:
        sys.path.insert(0, site_packages)
        return True
    return False


def get_krita_executable_path():
    """
    Returns the path hint for the Krita executable based on platform.
    """
    if sys.platform == "win32":
        return r"C:\Program Files\Krita (x64)\bin\krita.exe"
    elif sys.platform == "darwin":
        return "/Applications/krita.app/Contents/MacOS/krita"
    else:  # Linux
        return "/usr/bin/krita"


def get_platform_info():
    """Returns a dict with platform information for debugging."""
    return {
        "platform": sys.platform,
        "python_version": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "krita_pykrita_dir": get_krita_pykrita_dir(),
        "artkrit_temp_dir": get_artkrit_temp_dir(),
        "venv_site_packages": get_venv_site_packages(),
    }
