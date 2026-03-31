#!/usr/bin/env python3
"""Sniff the Windows clipboard to discover MuseScore's format name.

Usage:
    1. Open MuseScore on Windows
    2. Select a fretboard diagram in a score
    3. Press Ctrl+C to copy it
    4. Run: python sniff_clipboard_win.py

The script lists all clipboard formats and their data, flagging any
that contain MuseScore XML (FretDiagram, EngravingItem). If found,
it prints the exact format name to use in ms-clipboard.py.

    python sniff_clipboard_win.py --json    # machine-readable output
"""

import ctypes
import ctypes.wintypes
import json as json_mod
import sys

if sys.platform != "win32":
    print("This script is for Windows only.")
    sys.exit(1)

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

# Set proper types
user32.OpenClipboard.argtypes = [ctypes.wintypes.HWND]
user32.OpenClipboard.restype = ctypes.wintypes.BOOL
user32.CloseClipboard.restype = ctypes.wintypes.BOOL
user32.EnumClipboardFormats.argtypes = [ctypes.wintypes.UINT]
user32.EnumClipboardFormats.restype = ctypes.wintypes.UINT
user32.GetClipboardData.argtypes = [ctypes.wintypes.UINT]
user32.GetClipboardData.restype = ctypes.wintypes.HANDLE
user32.GetClipboardFormatNameW.argtypes = [
    ctypes.wintypes.UINT, ctypes.wintypes.LPWSTR, ctypes.c_int,
]
user32.GetClipboardFormatNameW.restype = ctypes.c_int
kernel32.GlobalSize.argtypes = [ctypes.wintypes.HGLOBAL]
kernel32.GlobalSize.restype = ctypes.c_size_t
kernel32.GlobalLock.argtypes = [ctypes.wintypes.HGLOBAL]
kernel32.GlobalLock.restype = ctypes.wintypes.LPVOID
kernel32.GlobalUnlock.argtypes = [ctypes.wintypes.HGLOBAL]
kernel32.GlobalUnlock.restype = ctypes.wintypes.BOOL

STANDARD_FORMATS = {
    1: "CF_TEXT", 2: "CF_BITMAP", 3: "CF_METAFILEPICT",
    4: "CF_SYLK", 5: "CF_DIF", 6: "CF_TIFF",
    7: "CF_OEMTEXT", 8: "CF_DIB", 9: "CF_PALETTE",
    10: "CF_PENDATA", 11: "CF_RIFF", 12: "CF_WAVE",
    13: "CF_UNICODETEXT", 14: "CF_ENHMETAFILE",
    15: "CF_HDROP", 16: "CF_LOCALE", 17: "CF_DIBV5",
}

MUSESCORE_MARKERS = ["FretDiagram", "EngravingItem", "fretDiagram"]


def get_format_name(fmt: int) -> str:
    """Get the name of a clipboard format."""
    buf = ctypes.create_unicode_buffer(256)
    length = user32.GetClipboardFormatNameW(fmt, buf, 256)
    if length > 0:
        return buf.value
    return STANDARD_FORMATS.get(fmt, f"Unknown({fmt})")


def sniff_formats():
    """Enumerate all clipboard formats and return structured results."""
    if not user32.OpenClipboard(None):
        print("Failed to open clipboard. Is another app holding it?")
        sys.exit(1)

    formats = []
    musescore_formats = []

    try:
        fmt = 0
        while True:
            fmt = user32.EnumClipboardFormats(fmt)
            if fmt == 0:
                break

            name = get_format_name(fmt)
            handle = user32.GetClipboardData(fmt)
            size = 0
            preview = ""
            is_musescore = False

            if handle:
                size = kernel32.GlobalSize(handle)
                if 0 < size < 100000:
                    ptr = kernel32.GlobalLock(handle)
                    if ptr:
                        raw = ctypes.string_at(ptr, min(size, 500))
                        kernel32.GlobalUnlock(handle)
                        try:
                            text = raw.decode("utf-8", errors="replace")
                            preview = text[:200].replace("\n", "\\n")
                        except Exception:
                            preview = f"[binary, {size} bytes]"

            # Detect MuseScore data
            if any(m in preview for m in MUSESCORE_MARKERS) or "musescore" in name.lower():
                is_musescore = True
                musescore_formats.append(name)

            formats.append({
                "id": fmt,
                "name": name,
                "size": size,
                "preview": preview,
                "is_musescore": is_musescore,
            })

    finally:
        user32.CloseClipboard()

    return formats, musescore_formats


def main():
    use_json = "--json" in sys.argv

    formats, musescore_formats = sniff_formats()

    if use_json:
        print(json_mod.dumps({
            "formats": formats,
            "musescore_formats": musescore_formats,
        }, indent=2))
        return

    print("Clipboard formats:")
    print("=" * 60)

    for f in formats:
        marker = " *** MUSESCORE ***" if f["is_musescore"] else ""
        print(f"\nFormat {f['id']}: {f['name']} ({f['size']} bytes){marker}")
        if f["preview"]:
            print(f"  Preview: {f['preview']}")

    print("\n" + "=" * 60)

    if musescore_formats:
        print(f"\nMuseScore format(s) detected: {', '.join(musescore_formats)}")
        print(f"\nTo use in ms-clipboard.py, set MUSESCORE_MIME = \"{musescore_formats[0]}\"")
    else:
        print("\nNo MuseScore format detected in clipboard.")
        print("Make sure you copied a fretboard diagram (Ctrl+C) in MuseScore first.")

    print("\nReport findings at: https://github.com/siege-analytics/musescore4-chord-library-plugin/issues")


if __name__ == "__main__":
    main()
