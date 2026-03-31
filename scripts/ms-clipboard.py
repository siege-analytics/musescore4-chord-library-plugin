#!/usr/bin/env python3
"""Write MuseScore fretboard diagram XML to the system clipboard.

Cross-platform replacement for ms-clipboard (Swift, macOS-only).
Reads XML from a file and writes it to the system clipboard with
MuseScore's internal MIME type.

Usage:
    python ms-clipboard.py paste-clipboard.xml

Platform support:
    macOS:   Uses pyobjc (AppKit.NSPasteboard) or falls back to compiled Swift tool
    Windows: Uses ctypes (Win32 API)
    Linux:   Uses xclip with custom MIME type

MuseScore MIME type (src/engraving/dom/mscore.h):
    application/musescore/symbol

Platform-specific clipboard format names:
    macOS:   com.trolltech.anymime.application--musescore--symbol (Qt UTI conversion)
    Windows: "application/musescore/symbol" (RegisterClipboardFormat name)
    Linux:   application/musescore/symbol (X11 atom via xclip)
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

    Qt on Windows registers custom MIME types as clipboard format names
    via RegisterClipboardFormat, using the MIME type string as the format
    name. MuseScore's internal constant is "application/musescore/symbol"
    (defined in src/engraving/dom/mscore.h as mimeSymbolFormat).

    We register all plausible format names and write data to each, since
    RegisterClipboardFormat always succeeds (it returns the existing ID if
    already registered, or creates a new one). This ensures we match
    whichever format Qt actually registered at runtime.

    If MuseScore's cmd("paste") doesn't pick up the data, use
    scripts/sniff_clipboard_win.py to discover the actual format name.
    """
    try:
        import ctypes
        import ctypes.wintypes

        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32

        # Set proper return/argument types for safety
        user32.RegisterClipboardFormatW.argtypes = [ctypes.wintypes.LPCWSTR]
        user32.RegisterClipboardFormatW.restype = ctypes.wintypes.UINT
        user32.OpenClipboard.argtypes = [ctypes.wintypes.HWND]
        user32.OpenClipboard.restype = ctypes.wintypes.BOOL
        user32.EmptyClipboard.restype = ctypes.wintypes.BOOL
        user32.SetClipboardData.argtypes = [ctypes.wintypes.UINT, ctypes.wintypes.HANDLE]
        user32.SetClipboardData.restype = ctypes.wintypes.HANDLE
        user32.CloseClipboard.restype = ctypes.wintypes.BOOL
        kernel32.GlobalAlloc.argtypes = [ctypes.wintypes.UINT, ctypes.c_size_t]
        kernel32.GlobalAlloc.restype = ctypes.wintypes.HGLOBAL
        kernel32.GlobalLock.argtypes = [ctypes.wintypes.HGLOBAL]
        kernel32.GlobalLock.restype = ctypes.wintypes.LPVOID
        kernel32.GlobalUnlock.argtypes = [ctypes.wintypes.HGLOBAL]
        kernel32.GlobalUnlock.restype = ctypes.wintypes.BOOL

        GMEM_MOVEABLE = 0x0002
        GMEM_ZEROINIT = 0x0040

        # Register all plausible format names. Qt's default behavior maps
        # custom MIME types to Windows clipboard formats using the MIME
        # string itself. The primary format is what MuseScore defines in
        # mscore.h; the others are fallbacks in case Qt wraps it.
        format_names = [
            MUSESCORE_MIME,                                                     # primary: matches mscore.h
            "application/x-qt-windows-mime;value=\"" + MUSESCORE_MIME + "\"",   # Qt wrapper variant
        ]

        registered = []
        for name in format_names:
            fmt = user32.RegisterClipboardFormatW(name)
            if fmt:
                registered.append((name, fmt))
                print(f"Registered clipboard format: {name} -> {fmt}", file=sys.stderr)

        if not registered:
            print("Failed to register any clipboard format", file=sys.stderr)
            return False

        if not user32.OpenClipboard(None):
            print("Failed to open clipboard", file=sys.stderr)
            return False

        try:
            user32.EmptyClipboard()

            success = False
            for name, fmt in registered:
                # Each format needs its own GlobalAlloc (clipboard owns the memory)
                size = len(data) + 1
                hmem = kernel32.GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, size)
                if not hmem:
                    print(f"Failed to allocate memory for {name}", file=sys.stderr)
                    continue

                ptr = kernel32.GlobalLock(hmem)
                if not ptr:
                    print(f"Failed to lock memory for {name}", file=sys.stderr)
                    continue
                ctypes.memmove(ptr, data, len(data))
                kernel32.GlobalUnlock(hmem)

                result = user32.SetClipboardData(fmt, hmem)
                if result:
                    print(f"Set clipboard data for: {name}", file=sys.stderr)
                    success = True
                else:
                    print(f"SetClipboardData failed for: {name}", file=sys.stderr)

            return success
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
