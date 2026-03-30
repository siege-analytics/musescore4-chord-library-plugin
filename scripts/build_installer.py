#!/usr/bin/env python3
"""Build distributable installer packages for the Chord Library plugin.

Creates platform-specific zip archives containing the plugin files and
an install script that non-programmers can double-click to install.

Usage:
    python scripts/build_installer.py                  # Build all platforms
    python scripts/build_installer.py --platform mac   # Mac only
    python scripts/build_installer.py --platform win   # Windows only
    python scripts/build_installer.py --output dist/   # Custom output directory
"""

import argparse
import os
import shutil
import stat
import subprocess
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PLUGIN_DIR = REPO_ROOT / "plugin"
VERSION = "1.2.0"
PLUGIN_NAME = "chordlibrary"

# Files to include in the distribution
PLUGIN_FILES = [
    "plugin/ChordLibrary.qml",
    "plugin/model/LibraryModel.qml",
    "plugin/model/Transposer.js",
    "plugin/model/VoicingInserter.qml",
    "plugin/ui/FilterBar.qml",
    "plugin/ui/PanelView.qml",
    "plugin/ui/SearchBar.qml",
    "plugin/ui/VoicingCard.qml",
    "plugin/ui/VoicingGrid.qml",
    "config/contexts.json",
    "config/tunings/standard.json",
    "config/tunings/7string-low-b.json",
    "config/tunings/dadgad.json",
    "config/tunings/all-fourths.json",
    "scripts/ms-clipboard.swift",
    "scripts/generate_mscz.py",
]

MAC_INSTALL_SCRIPT = r'''#!/bin/bash
# Chord Library Plugin Installer for macOS
# Double-click this file to install the plugin into MuseScore Studio.

set -e

PLUGIN_NAME="chordlibrary"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/plugin"

# MuseScore 4 plugin directories (check in order of preference)
MS_DIRS=(
    "$HOME/Documents/MuseScore4/Plugins"
    "$HOME/Documents/MuseScore Studio/Plugins"
)

# Find the right MuseScore plugins directory
DEST_DIR=""
for dir in "${MS_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        DEST_DIR="$dir"
        break
    fi
done

# If neither exists, try to create the most common one
if [ -z "$DEST_DIR" ]; then
    DEST_DIR="$HOME/Documents/MuseScore4/Plugins"
    echo "Creating MuseScore plugins directory: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

TARGET="$DEST_DIR/$PLUGIN_NAME"

echo "======================================"
echo "  Chord Library Plugin Installer"
echo "======================================"
echo ""
echo "Source:  $SOURCE_DIR"
echo "Target:  $TARGET"
echo ""

# Check source files exist
if [ ! -f "$SOURCE_DIR/ChordLibrary.qml" ]; then
    echo "ERROR: Plugin files not found in $SOURCE_DIR"
    echo "Make sure the 'plugin' folder is next to this installer script."
    echo ""
    read -p "Press Enter to close..."
    exit 1
fi

# Back up existing installation
if [ -d "$TARGET" ]; then
    BACKUP="$TARGET.backup.$(date +%Y%m%d%H%M%S)"
    echo "Existing installation found. Backing up to:"
    echo "  $BACKUP"
    mv "$TARGET" "$BACKUP"
    echo ""
fi

# Copy plugin files
echo "Installing plugin files..."
mkdir -p "$TARGET"
mkdir -p "$TARGET/model"
mkdir -p "$TARGET/ui"

cp "$SOURCE_DIR/ChordLibrary.qml" "$TARGET/chordlibrary.qml"
cp "$SOURCE_DIR/model/"* "$TARGET/model/"
cp "$SOURCE_DIR/ui/"* "$TARGET/ui/"

# Copy tuning configs
mkdir -p "$TARGET/tunings"
if [ -d "$SCRIPT_DIR/config/tunings" ]; then
    cp "$SCRIPT_DIR/config/tunings/"*.json "$TARGET/tunings/"
fi
if [ -f "$SCRIPT_DIR/config/contexts.json" ]; then
    mkdir -p "$DEST_DIR/../config"
    cp "$SCRIPT_DIR/config/contexts.json" "$DEST_DIR/../config/"
fi

# Copy helper scripts
mkdir -p "$TARGET/scripts"
if [ -f "$SCRIPT_DIR/scripts/generate_mscz.py" ]; then
    cp "$SCRIPT_DIR/scripts/generate_mscz.py" "$TARGET/scripts/"
fi

# Compile ms-clipboard (Swift CLI for clipboard paste)
if [ -f "$SCRIPT_DIR/scripts/ms-clipboard.swift" ]; then
    echo "Compiling ms-clipboard (diagram clipboard writer)..."
    if swiftc -o "$TARGET/ms-clipboard" "$SCRIPT_DIR/scripts/ms-clipboard.swift" -framework AppKit 2>/dev/null; then
        echo "  ms-clipboard compiled successfully."
    else
        echo "  WARNING: Could not compile ms-clipboard."
        echo "  Diagram insertion with dots requires Xcode Command Line Tools."
        echo "  Install with: xcode-select --install"
    fi
fi

# Install launchd agent for clipboard bridge
PLIST_NAME="com.siegeanalytics.chord-library-clipboard"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$PLIST_NAME.plist"

if [ -f "$TARGET/ms-clipboard" ]; then
    echo "Installing clipboard bridge agent..."
    mkdir -p "$PLIST_DIR"
    cat > "$PLIST_PATH" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET/ms-clipboard</string>
        <string>$TARGET/paste-clipboard.xml</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$TARGET/paste-clipboard.xml</string>
    </array>
    <key>StandardOutPath</key>
    <string>/tmp/chord-library-clipboard.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/chord-library-clipboard.log</string>
</dict>
</plist>
PLIST_EOF
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"
    echo "  Clipboard bridge agent installed and loaded."
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Open (or restart) MuseScore Studio"
echo "  2. Go to Plugins menu"
echo "  3. Enable 'Chord Library'"
echo ""
read -p "Press Enter to close..."
'''

MAC_UNINSTALL_SCRIPT = r'''#!/bin/bash
# Chord Library Plugin Uninstaller for macOS
# Double-click this file to remove the plugin from MuseScore Studio.

set -e

PLUGIN_NAME="chordlibrary"

MS_DIRS=(
    "$HOME/Documents/MuseScore4/Plugins"
    "$HOME/Documents/MuseScore Studio/Plugins"
)

echo "======================================"
echo "  Chord Library Plugin Uninstaller"
echo "======================================"
echo ""

FOUND=0
for dir in "${MS_DIRS[@]}"; do
    TARGET="$dir/$PLUGIN_NAME"
    if [ -d "$TARGET" ]; then
        echo "Found installation at: $TARGET"
        read -p "Remove it? (y/N) " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            rm -rf "$TARGET"
            echo "Removed."
            FOUND=1
        else
            echo "Skipped."
        fi
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "No installation found."
fi

# Remove launchd agent
PLIST_NAME="com.siegeanalytics.chord-library-clipboard"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
if [ -f "$PLIST_PATH" ]; then
    echo ""
    echo "Removing clipboard bridge agent..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo "  Removed."
fi

echo ""
echo "If MuseScore Studio is open, restart it to complete the removal."
echo ""
read -p "Press Enter to close..."
'''

WIN_INSTALL_SCRIPT = r'''@echo off
REM Chord Library Plugin Installer for Windows
REM Double-click this file to install the plugin into MuseScore Studio.

setlocal enabledelayedexpansion

set PLUGIN_NAME=chordlibrary
set SCRIPT_DIR=%~dp0
set SOURCE_DIR=%SCRIPT_DIR%plugin

echo ======================================
echo   Chord Library Plugin Installer
echo ======================================
echo.

REM Check for MuseScore plugins directory
set DEST_DIR=
if exist "%USERPROFILE%\Documents\MuseScore4\Plugins" (
    set "DEST_DIR=%USERPROFILE%\Documents\MuseScore4\Plugins"
) else if exist "%USERPROFILE%\Documents\MuseScore Studio\Plugins" (
    set "DEST_DIR=%USERPROFILE%\Documents\MuseScore Studio\Plugins"
) else (
    set "DEST_DIR=%USERPROFILE%\Documents\MuseScore4\Plugins"
    echo Creating MuseScore plugins directory...
    mkdir "%DEST_DIR%" 2>nul
)

set "TARGET=%DEST_DIR%\%PLUGIN_NAME%"

echo Source:  %SOURCE_DIR%
echo Target:  %TARGET%
echo.

REM Check source files exist
if not exist "%SOURCE_DIR%\ChordLibrary.qml" (
    echo ERROR: Plugin files not found in %SOURCE_DIR%
    echo Make sure the 'plugin' folder is next to this installer script.
    echo.
    pause
    exit /b 1
)

REM Back up existing installation
if exist "%TARGET%" (
    set BACKUP=%TARGET%.backup.%date:~-4%%date:~4,2%%date:~7,2%
    echo Existing installation found. Backing up to:
    echo   !BACKUP!
    move "%TARGET%" "!BACKUP!" >nul
    echo.
)

REM Copy plugin files
echo Installing plugin files...
mkdir "%TARGET%" 2>nul
mkdir "%TARGET%\model" 2>nul
mkdir "%TARGET%\ui" 2>nul

copy "%SOURCE_DIR%\ChordLibrary.qml" "%TARGET%\chordlibrary.qml" >nul
copy "%SOURCE_DIR%\model\*" "%TARGET%\model\" >nul
copy "%SOURCE_DIR%\ui\*" "%TARGET%\ui\" >nul

echo.
echo Installation complete!
echo.
echo Next steps:
echo   1. Open (or restart) MuseScore Studio
echo   2. Go to Plugins menu
echo   3. Enable 'Chord Library'
echo.
pause
'''

WIN_UNINSTALL_SCRIPT = r'''@echo off
REM Chord Library Plugin Uninstaller for Windows
REM Double-click this file to remove the plugin from MuseScore Studio.

setlocal enabledelayedexpansion

set PLUGIN_NAME=chordlibrary

echo ======================================
echo   Chord Library Plugin Uninstaller
echo ======================================
echo.

set FOUND=0

for %%d in (
    "%USERPROFILE%\Documents\MuseScore4\Plugins"
    "%USERPROFILE%\Documents\MuseScore Studio\Plugins"
) do (
    if exist "%%~d\%PLUGIN_NAME%" (
        echo Found installation at: %%~d\%PLUGIN_NAME%
        set /p confirm="Remove it? (y/N) "
        if /i "!confirm!"=="y" (
            rmdir /s /q "%%~d\%PLUGIN_NAME%"
            echo Removed.
            set FOUND=1
        ) else (
            echo Skipped.
        )
    )
)

if %FOUND%==0 (
    echo No installation found.
)

echo.
echo If MuseScore Studio is open, restart it to complete the removal.
echo.
pause
'''


def build_zip(platform: str, output_dir: Path) -> Path:
    """Build a zip archive for the given platform."""
    output_dir.mkdir(parents=True, exist_ok=True)
    zip_name = f"ChordLibrary-{VERSION}-{platform}"
    zip_path = output_dir / f"{zip_name}.zip"

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        # Add plugin files
        for rel_path in PLUGIN_FILES:
            src = REPO_ROOT / rel_path
            if src.exists():
                zf.write(src, f"{zip_name}/{rel_path}")
            else:
                print(f"  WARNING: {rel_path} not found, skipping",
                      file=sys.stderr)

        # Add README
        readme = REPO_ROOT / "README.md"
        if readme.exists():
            zf.write(readme, f"{zip_name}/README.md")

        # Add platform-specific install/uninstall scripts
        if platform == "mac":
            zf.writestr(
                f"{zip_name}/Install Chord Library.command",
                MAC_INSTALL_SCRIPT,
            )
            zf.writestr(
                f"{zip_name}/Uninstall Chord Library.command",
                MAC_UNINSTALL_SCRIPT,
            )
        elif platform == "win":
            zf.writestr(
                f"{zip_name}/Install Chord Library.bat",
                WIN_INSTALL_SCRIPT,
            )
            zf.writestr(
                f"{zip_name}/Uninstall Chord Library.bat",
                WIN_UNINSTALL_SCRIPT,
            )

    # Make Mac .command files executable after extraction
    # (zip preserves Unix permissions if set correctly)
    if platform == "mac":
        _set_zip_executable(zip_path, zip_name)

    return zip_path


def _set_zip_executable(zip_path: Path, zip_name: str) -> None:
    """Set executable permission bits on .command files inside the zip."""
    import struct

    temp_path = zip_path.with_suffix(".tmp.zip")
    with zipfile.ZipFile(zip_path, "r") as zin:
        with zipfile.ZipFile(temp_path, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if item.filename.endswith(".command"):
                    # Set Unix executable permissions (rwxr-xr-x)
                    item.external_attr = 0o755 << 16
                zout.writestr(item, data)
    temp_path.replace(zip_path)


def build_mac_pkg(output_dir: Path) -> Path | None:
    """Build a macOS .pkg installer using pkgbuild (macOS only)."""
    if sys.platform != "darwin":
        print("  Skipping .pkg build (not on macOS)", file=sys.stderr)
        return None

    output_dir.mkdir(parents=True, exist_ok=True)
    pkg_path = output_dir / f"ChordLibrary-{VERSION}.pkg"

    # Create a staging directory with the correct install layout
    staging = output_dir / "_pkg_staging"
    if staging.exists():
        shutil.rmtree(staging)

    # Stage files into the target structure
    # MuseScore looks in ~/Documents/MuseScore4/Plugins/
    # pkgbuild --install-location puts files relative to user home
    plugin_dest = staging / "Documents" / "MuseScore4" / "Plugins" / PLUGIN_NAME
    plugin_dest.mkdir(parents=True)
    (plugin_dest / "model").mkdir()
    (plugin_dest / "ui").mkdir()

    # Copy files
    shutil.copy2(
        REPO_ROOT / "plugin" / "ChordLibrary.qml",
        plugin_dest / "chordlibrary.qml",
    )
    for f in (REPO_ROOT / "plugin" / "model").iterdir():
        if f.is_file():
            shutil.copy2(f, plugin_dest / "model" / f.name)
    for f in (REPO_ROOT / "plugin" / "ui").iterdir():
        if f.is_file():
            shutil.copy2(f, plugin_dest / "ui" / f.name)

    # Build .pkg
    try:
        result = subprocess.run(
            [
                "pkgbuild",
                "--root", str(staging),
                "--identifier", "com.siegeanalytics.chordlibrary",
                "--version", VERSION,
                "--install-location", os.path.expanduser("~"),
                str(pkg_path),
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(f"  pkgbuild failed: {result.stderr}", file=sys.stderr)
            return None
    except FileNotFoundError:
        print("  pkgbuild not found (need Xcode CLI tools)", file=sys.stderr)
        return None
    finally:
        shutil.rmtree(staging, ignore_errors=True)

    return pkg_path


def main():
    parser = argparse.ArgumentParser(
        description="Build Chord Library plugin installers"
    )
    parser.add_argument(
        "--platform",
        choices=["mac", "win", "all"],
        default="all",
        help="Target platform (default: all)",
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        default=REPO_ROOT / "dist",
        help="Output directory (default: dist/)",
    )
    parser.add_argument(
        "--pkg",
        action="store_true",
        help="Also build macOS .pkg installer (macOS only)",
    )
    args = parser.parse_args()

    platforms = ["mac", "win"] if args.platform == "all" else [args.platform]

    print(f"Building Chord Library v{VERSION} installers\n")

    for platform in platforms:
        print(f"  Building {platform} zip...")
        path = build_zip(platform, args.output)
        size_kb = path.stat().st_size / 1024
        print(f"    {path.name} ({size_kb:.0f} KB)")

    if args.pkg or (args.platform in ("mac", "all") and sys.platform == "darwin"):
        print(f"\n  Building macOS .pkg...")
        pkg = build_mac_pkg(args.output)
        if pkg:
            size_kb = pkg.stat().st_size / 1024
            print(f"    {pkg.name} ({size_kb:.0f} KB)")

    print(f"\nDone. Output in {args.output}/")


if __name__ == "__main__":
    main()
