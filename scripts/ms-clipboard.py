#!/usr/bin/env python3
"""Write MuseScore fretboard diagram XML to the system clipboard.

Cross-platform replacement for ms-clipboard (Swift, macOS-only).
Reads XML from a file and writes it to the system clipboard with
MuseScore's internal MIME type.

Usage:
    python ms-clipboard.py paste-clipboard.xml

Platform support:
    macOS:   Uses pyobjc (AppKit.NSPasteboard) or falls back to pbcopy
    Windows: Uses ctypes + win32clipboard
    Linux:   Uses xclip with custom MIME type

MuseScore clipboard type:
    com.trolltech.anymime.application--musescore--symbol
"""

import os
import platform
import subprocess
import sys
from pathlib import Path

MUSESCORE_MIME = "application/musescore/symbol"
# macOS pasteboard type (Qt's internal MIME → UTI conversion)
MACOS_UTI = "com.trolltech.anymime.application--musescore--symbol"


def write_clipboard_macos(data: bytes) -> bool:
    """Write to macOS pasteboard using AppKit or pbcopy fallback."""
    # Try AppKit (pyobjc)
    try:
        from AppKit import NSPasteboard, NSPasteboardType

        pb = NSPasteboard.generalPasteboard()
        paste_type = NSPasteboardType(MACOS_UTI)
        pb.clearContents()
        pb.setData_forType_(data, paste_type)
        return True
    except ImportError:
        pass

    # Try the compiled Swift tool (faster, no pyobjc needed)
    swift_tool = Path(__file__).parent.parent / "ms-clipboard"
    if not swift_tool.exists():
        swift_tool = Path(__file__).parent / "ms-clipboard"
    if swift_tool.exists():
        # Write to temp file and call the Swift tool
        import tempfile

        with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as f:
            f.write(data)
            tmp = f.name
        try:
            result = subprocess.run(
                [str(swift_tool), tmp], capture_output=True, timeout=5
            )
            return result.returncode == 0
        finally:
            os.unlink(tmp)

    print("Warning: No clipboard method available on macOS.", file=sys.stderr)
    print("Install pyobjc: pip install pyobjc-framework-Cocoa", file=sys.stderr)
    return False


def write_clipboard_windows(data: bytes) -> bool:
    """Write to Windows clipboard using ctypes.

    NOTE: The exact clipboard format name MuseScore uses on Windows is
    speculative. Qt on Windows maps MIME types to clipboard format names
    differently than macOS. If MuseScore's cmd("paste") doesn't pick up
    the data, try running MuseScore, copying a fretboard diagram (Ctrl+C),
    then use scripts/sniff_clipboard_win.py to discover the format name.

    Known possibilities:
    - "application/musescore/symbol" (our MIME type)
    - Qt's internal format: "application/x-qt-windows-mime;value=..."
    - A numeric format registered by Qt at runtime
    """
    try:
        import ctypes

        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32

        # Try multiple format names — Qt on Windows may use any of these
        format_names = [
            MUSESCORE_MIME,
            "application/x-qt-windows-mime;value=\"" + MUSESCORE_MIME + "\"",
            "MuseScore Symbol",
        ]

        fmt = 0
        for name in format_names:
            fmt = user32.RegisterClipboardFormatW(name)
            if fmt:
                print(f"Registered clipboard format: {name} → {fmt}", file=sys.stderr)
                break

        if not fmt:
            print("Failed to register any clipboard format", file=sys.stderr)
            print("Tried: " + ", ".join(format_names), file=sys.stderr)
            return False

        if not user32.OpenClipboard(0):
            print("Failed to open clipboard", file=sys.stderr)
            return False

        try:
            user32.EmptyClipboard()

            # Allocate global memory
            size = len(data) + 1
            hmem = kernel32.GlobalAlloc(0x0042, size)  # GMEM_MOVEABLE | GMEM_ZEROINIT
            if not hmem:
                print("Failed to allocate clipboard memory", file=sys.stderr)
                return False

            ptr = kernel32.GlobalLock(hmem)
            ctypes.memmove(ptr, data, len(data))
            kernel32.GlobalUnlock(hmem)

            result = user32.SetClipboardData(fmt, hmem)
            return bool(result)
        finally:
            user32.CloseClipboard()

    except Exception as e:
        print(f"Windows clipboard error: {e}", file=sys.stderr)
        return False


def write_clipboard_linux(data: bytes) -> bool:
    """Write to Linux clipboard using xclip."""
    try:
        # xclip with custom target type
        proc = subprocess.Popen(
            ["xclip", "-selection", "clipboard", "-t", MUSESCORE_MIME, "-i"],
            stdin=subprocess.PIPE,
        )
        proc.communicate(input=data, timeout=5)
        return proc.returncode == 0
    except FileNotFoundError:
        print("xclip not found. Install: sudo apt install xclip", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Linux clipboard error: {e}", file=sys.stderr)
        return False


def write_clipboard(data: bytes) -> bool:
    """Write data to the system clipboard with MuseScore's MIME type."""
    system = platform.system()
    if system == "Darwin":
        return write_clipboard_macos(data)
    elif system == "Windows":
        return write_clipboard_windows(data)
    elif system == "Linux":
        return write_clipboard_linux(data)
    else:
        print(f"Unsupported platform: {system}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <xml-file>", file=sys.stderr)
        sys.exit(1)

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"File not found: {path}", file=sys.stderr)
        sys.exit(1)

    data = path.read_bytes()
    if not data:
        print("Empty file", file=sys.stderr)
        sys.exit(1)

    if write_clipboard(data):
        print(
            f"Wrote {len(data)} bytes to clipboard as MuseScore symbol",
            file=sys.stderr,
        )
    else:
        print("Failed to write to clipboard", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
